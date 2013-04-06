module Sorcery
  module Controller
    module Submodules
      # This submodule helps you login users from external auth providers such as Twitter.
      # This is the controller part which handles the http requests and tokens passed between the app and the provider.
      module External
        def self.included(base)
          base.send(:include, InstanceMethods)
          Config.module_eval do
            class << self
              attr_reader :external_providers                           # external providers like twitter.
              attr_accessor :ca_file                                    # path to ca_file. By default use a internal ca-bundle.crt.

              def merge_external_defaults!
                @defaults.merge!(:@external_providers => [],
                                 :@ca_file => File.join(File.expand_path(File.dirname(__FILE__)), 'external/protocols/certs/ca-bundle.crt'))
              end

              def external_providers=(providers)
                providers.each do |provider|
                  include Providers.const_get(provider.to_s.split("_").map {|p| p.capitalize}.join(""))
                end
              end
            end
            merge_external_defaults!
          end
        end

        module InstanceMethods
          protected

          # sends user to authenticate at the provider's website.
          # after authentication the user is redirected to the callback defined in the provider config
          def login_at(provider_name, args = {})
            provider = Config.send(provider_name)
            if provider.callback_url.present? && provider.callback_url[0] == '/'
              uri = URI.parse(request.url.gsub(/\?.*$/,''))
              uri.path = ''
              uri.query = nil
              uri.scheme = 'https' if(request.env['HTTP_X_FORWARDED_PROTO'] == 'https')
              host = uri.to_s
              provider.callback_url = "#{host}#{provider.callback_url}"
            end
            if provider.has_callback?
              redirect_to provider.login_url(params,session)
            else
              #provider.login(args)
            end
          end

          def get_user_hash_from(provider_name)
            provider = Config.send(provider_name)
            provider.process_callback(params,session) unless provider.access_token
            user_hash = provider.get_user_hash

            attrs = {}
            provider.user_info_mapping.each do |k,v|
              if (varr = v.split("/")).size > 1
                attribute_value = varr.inject(user_hash[:user_info]) {|hash, value| hash[value]} rescue nil
                attribute_value.nil? ? attrs : attrs.merge!(k => attribute_value)
              else
                attrs.merge!(k => user_hash[:user_info][v])
              end
            end
            user_hash[:mapped_info] = attrs

            user_hash
          end

          # tries to login the user from provider's callback
          def login_from(provider_name)
            user_hash = get_user_hash_from(provider_name)
            if user = user_class.load_from_provider(provider_name, user_hash[:uid].to_s)
              return_to_url = session[:return_to_url]
              reset_session
              session[:return_to_url] = return_to_url
              auto_login(user)
              after_login!(user)
              user
            end
          end

          # Login external user with access token obtained from an authorization
          # server by the client-side application.
          #
          # Requirements: OAuth 2.0 Protocol. (Implicit Grant)
          #
          # Params:
          # +provider_name+:: name of provider.
          # +access_token_hash+:: access token properties from client-side app.
          #
          def login_from_client_side(provider_name, access_token_hash)
            provider = Config.send(provider_name)

            return nil if provider.oauth_version == '1.0'
            if ! ( access_token_hash.key?(:access_token) ||
                   access_token_hash.key?('access_token') )

               raise 'Missing access_token parameter in properties hash'
            end


            client_options  = provider.client_options
            provider_client = provider.build_client(client_options)
            provider.access_token = ::OAuth2::AccessToken.from_hash(provider_client,
                                                                    access_token_hash)

            user_hash = provider.get_user_hash rescue nil # bad token
            if user_hash
              user = user_class.load_from_provider(provider_name, user_hash[:uid].to_s)
              if user
                auto_login(user)
                after_login!(user)
                user
              end
            else
              nil
            end
          end

          # Login external user from access token,
          # create user if it doesn't exist in database.
          def login_or_create_from_client_side(provider_name, access_token_hash)
            user = login_from_client_side(provider_name, access_token_hash)
            if ! user
              provider  = Config.send(provider_name)
              user_hash = provider.get_user_hash rescue nil
              if user_hash && !!user_hash[:uid]
                user = create_from(provider_name, user_hash)
                auto_login(user)
                after_login!(user)
              end
            end
            user
          end

          # get provider access account
          def access_token(provider_name)
            provider = Config.send(provider_name)
            provider.access_token
          end

          # If user is logged, he can add all available providers into his account
          def add_provider_to_user(provider_name)
            user_hash = get_user_hash_from(provider_name)

            # first check to see if user has a particular authentication already
            return false if user_class.get_id_from_provider(provider_name, user_hash[:uid])

            user = current_user.add_provider(provider_name.to_s, user_hash[:uid])
            user.save(:validate => false)
          end

          # Initialize new user from provider informations.
          # If a provider doesn't give required informations or username/email is already taken,
          # we store provider/user infos into a session and can be rendered into registration form
          def create_and_validate_from(provider_name)
            user_hash = get_user_hash_from(provider_name)
            user = user_class.new(user_hash[:mapped_info], :without_protection =>true)

            user.add_provider(user_hash[:uid], provider)

            config = user_class.sorcery_config
            session[:incomplete_user] = {
              :provider => {config.provider_uid_attribute_name => user_hash[:uid], config.provider_attribute_name => provider_name},
              :user_hash => attrs
            } unless user.save

            return user
          end

          # this method automatically creates a new user from the data in the external user hash.
          # The mappings from user hash fields to user db fields are set at controller config.
          # If the hash field you would like to map is nested, use slashes. For example, Given a hash like:
          #
          #   "user" => {"name"=>"moishe"}
          #
          # You will set the mapping:
          #
          #   {:username => "user/name"}
          #
          # And this will cause 'moishe' to be set as the value of :username field.
          # Note: Be careful. This method skips validations model.
          # Instead you can pass a block, if the block returns false the user will not be created
          #
          #   create_from(provider) {|user| user.some_check }
          #
<<<<<<< HEAD
          def create_from(provider_name)
            user_hash = get_user_hash_from(provider_name)
            user = user_class.new(user_hash[:mapped_info], :without_protection =>true)
            if block_given?
              return false unless yield user
            end
=======
          def create_from(provider_name, user_hash = nil)
            provider_name = provider_name.to_sym
            provider = Config.send(provider_name)
            user_hash ||= provider.get_user_hash
            config = user_class.sorcery_config

            attrs = user_attrs(provider.user_info_mapping, user_hash)

>>>>>>> ec97aa5aab02d362bc51acac83b9d13fd1880082
            user_class.transaction do
              user.save(:validate => false)
              config = user_class.sorcery_config
              user_class.sorcery_config.authentications_class.create!({config.authentications_user_id_attribute_name => user.id, config.provider_attribute_name => provider_name, config.provider_uid_attribute_name => user_hash[:uid]})
            end
            @user
          end
        end
      end
    end
  end
end
