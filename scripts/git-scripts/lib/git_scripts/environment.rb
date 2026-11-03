# frozen_string_literal: true

module GitScripts
  class Environment
    class << self
      VERSION_REGEX = /^(\d+\.\d+\.\d+).*/

      def latest_environment_version(environment_name)
        environment_number = resolve_environment_number(environment_name)

        url = "https://author-p163316-e#{environment_number}.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"
        begin
          response = RestClient.get url

          VERSION_REGEX.match(response.body)[1]
        rescue StandardError => e
          puts "Failed to retrieve the latest environment version for #{name}"
          puts e

          exit 1
        end
      end

      def resolve_environment_number(aem_environment)
        aem_environment = aem_environment.to_s.downcase
        mapping = {
          'dev' => 1_757_025,
          'qa' => 1_779_100,
          'uat' => 1_779_207,
          'ppe' => 1_779_165,
          'prod' => 1_779_099
        }

        unless mapping.key? aem_environment
          valid_environment_names = mapping
            .map { |key, _value| "'#{key}'" }
            .join(', ')

          raise "Environment #{aem_environment} does not exist in this list: #{valid_environment_names}"
        end

        mapping[aem_environment]
      end
    end
  end
end
