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

          insert_into_file "#{model_file_path}.rb", "  authenticates_with_sorcery!\n", :after => after_expr
        end
      end

      def concerns
        copy_migration_files if migrations?
        if mongoid?
          copy_mongoid_concern_files 
        end
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
            unless submodule == "http_basic_auth" || submodule == "session_timeout"
              migration_template "migration/#{submodule}.rb", "db/migrate/sorcery_#{submodule}.rb"
            end
          end
        end        
      end

      def copy_mongoid_concern_files
        # Copy migration files except when you pass --no-migrations.
        return if no_migrations?
        include_mongoid_concerns = []

        if submodules.include? 'external'
          migration_template "mongoid/authentications.rb", "#{models_path}/authentications.rb"
        end

        migration_template "mongoid/core.rb", "#{model_file_path}/core.rb"
        include_mongoid_concerns << "  include #{model_class_name}::Core"

        if submodules
          submodules.each do |submodule|
            unless %w{http_basic_auth session_timeout authentications}.include? submodule
              migration_template "mongoid/#{submodule}.rb", "#{model_file_path}/#{submodule}.rb"
            end

            unless submodule == 'authentications'
              include_mongoid_concerns << "  include #{model_class_name}::#{submodule.to_s.camelize}"
            end
          end
        end 

        concerns_code = include_mongoid_concerns.join "\n"

        insert_into_file "#{model_file_path}.rb", "  #{concerns_code}\n", :after => after_expr

        if submodules.include? 'external'
          insert_into_file "#{model_file_path}.rb", "  embeds_many :authentications\n", after: include_mongoid_concerns.last        
        end
      end

      def mongoid?
        orm == :mongoid
      end

      def orm
        (options[:orm] || 'active_record').to_sym
      end

      def after_expr
        case orm
        when :active_record
          "class #{model_class_name} < ActiveRecord::Base\n"
        when :mongoid
          "include Mongoid::Document"
        when :mongo_mapper
          "include MongoMapper::Document"
        else
          "class #{model_class_name}\n.+\n"
          say "Attempted code generation in #{model_class_name}"
          say "Please check generated code in #{model_class_name} for potential syntax error."
          # raise "ORM #{orm} not yet supported for install generator"
        end
      end

      def migrations?
        options[:migrations]
      end

      def no_migrations?
        !migrations?
      end
      
      private

      # Either return the model passed in a classified form or return the default "User".
      def model_class_name
        options[:model] ? options[:model].classify : "User"
      end
    end
  end
end
