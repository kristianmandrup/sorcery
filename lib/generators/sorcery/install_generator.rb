require 'rails/generators/migration'

module Sorcery
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      
      source_root File.expand_path('../templates', __FILE__)
      
      argument :submodules, :optional => true, :type => :array, :banner => "submodules"
      
      class_option :model, :optional => true, :type => :string, :banner => "model",
                   :desc => "Specify the model class name if you will use anything other than 'User'"
                           
      class_option :migrations, :optional => true, :type => :boolean, :banner => "migrations",
                   :desc => "Specify if you want to add submodules to an existing model\n\t\t\t     # (will generate migrations files, and add submodules to config file)"
      
      class_option :orm, :optional => true, :type => :string, :banner => "ORM to generate models for",
                   :desc => "Specify which ORM to generate models for"

      
      # Copy the initializer file to config/initializers folder.
      def copy_initializer_file
        template "initializer.rb", "config/initializers/sorcery.rb" unless options[:migrations]
      end

      def configure_initializer_file
        # Add submodules to the initializer file.
        if submodules
          submodule_names = submodules.collect{ |submodule| ':' + submodule }

          gsub_file "config/initializers/sorcery.rb", /submodules = \[.*\]/ do |str|
            current_submodule_names = (str =~ /\[(.*)\]/ ? $1 : '').delete(' ').split(',')
            "submodules = [#{(current_submodule_names | submodule_names).join(', ')}]"
          end
        end

        # Generate the model and add 'authenticates_with_sorcery!' unless you passed --migrations
        unless migrations?
          generate "model #{model_class_name} --skip-migration"

          # if engine or mismatch with default orm specified
          gsub_file model_file, model_marker(:active_record) do |match|
            "\n  #{model_marker}"
          end

          insert_into_file model_file, "  authenticates_with_sorcery!\n", :after => model_marker
        end

        if submodules && submodules.include?("access_token")
          generate_access_token_model
        end

      end

      def concerns
        copy_migration_files if migrations?
        copy_mongoid_concern_files if mongoid?
      end

      
      # Define the next_migration_number method (necessary for the migration_template method to work)
      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          sleep 1 # make sure each time we get a different timestamp
          Time.new.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end

      protected

      def models_path
        "app/models"
      end

      def model_file
        "#{model_file_path}.rb"
      end

      def model_file_path
        "#{models_path}/#{model_class_name.underscore}"
      end

      # Copy the migrations files to db/migrate folder
      def copy_migration_files
        # Copy migration files except when you pass --no-migrations.
        return if no_migrations?

        migration_template "migration/core.rb", "db/migrate/sorcery_core.rb"

        if submodules
          submodules.each do |submodule|
            unless submodule == "http_basic_auth" || submodule == "session_timeout" || submodule == "core"
              migration_template "migration/#{submodule}.rb", "db/migrate/sorcery_#{submodule}.rb"
            end
          end
        end        
      end

      def copy_mongoid_concern_files
        return if migrations?

        include_mongoid_concerns = []

        if submodules.include? 'external'
          template "mongoid/external.rb", "#{models_path}/authentication.rb"
        end

        template "mongoid/core.rb", "#{model_file_path}/core.rb"
        include_mongoid_concerns << "  include #{model_class_name}::Core"

        if submodules
          submodules.each do |submodule|
            unless %w{http_basic_auth session_timeout authentications}.include? submodule
              template "mongoid/#{submodule}.rb", "#{model_file_path}/#{submodule}.rb"
            end

            unless submodule == 'external'
              include_mongoid_concerns << "  include #{model_class_name}::#{submodule.to_s.camelize}"
            end
          end
        end 

        concerns_code = include_mongoid_concerns.join "\n"

        insert_into_file "#{model_file_path}.rb", "#{concerns_code}\n", :after => model_marker

        if submodules.include? 'external'
          insert_into_file "#{model_file_path}.rb", "\n  embeds_many :authentications\n", after: include_mongoid_concerns.last
        end
      end

      def mongoid?
        orm == :mongoid
      end

      def active_record?
        orm == :active_record
      end

      def orm
        @orm ||= (options[:orm] || 'active_record').to_sym
      end

      def model_marker orm_name = nil
        orm_name ||= orm
        case orm_name
        when :active_record
          "< ActiveRecord::Base\n"
        when :mongoid
          "include Mongoid::Document\n"
        when :mongo_mapper
          "include MongoMapper::Document\n"
        else
          "class #{model_class_name}\n.+\n"
        end
      end

      def migrations?
        options[:migrations] || active_record?
      end

      def no_migrations?
        !migrations?
      end
      
      private

      # Either return the model passed in a classified form or return the default "User".
      def model_class_name
        options[:model] ? options[:model].classify : "User"
      end

      def generate_access_token_model
        access_token_class_name = 'AccessToken'
        access_token_model_file = "app/models/#{access_token_class_name.underscore}.rb"
        template "models/access_token.rb", access_token_model_file

        insert_into_file("app/models/#{model_class_name.underscore}.rb",
                         "\n  has_many :access_tokens, :dependent => :delete_all\n",
                         :after => "  authenticates_with_sorcery!")
      end
    end
  end
end
