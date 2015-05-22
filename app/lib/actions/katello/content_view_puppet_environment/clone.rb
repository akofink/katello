module Actions
  module Katello
    module ContentViewPuppetEnvironment
      class Clone < Actions::Base
        attr_accessor :new_puppet_environment

        def plan(from_version, options)
          environment = options[:environment]
          new_version = options[:new_version]
          source = from_version.content_view_puppet_environments.archived.first

          if environment
            clone = find_or_build_puppet_env(from_version, environment)
          else
            clone = find_or_build_puppet_archive(new_version)
          end

          sequence do
            if clone.new_record?
              plan_action(ContentViewPuppetEnvironment::Create, clone, true)
            else
              clone.content_view_version = from_version
              clone.save!
              plan_action(ContentViewPuppetEnvironment::Clear, clone)
            end

            self.new_puppet_environment = clone
            plan_action(Pulp::Repository::CopyPuppetModule,
                        source_pulp_id: source.pulp_id,
                        target_pulp_id: clone.pulp_id,
                        criteria: nil)

            concurrence do
              plan_action(Katello::Repository::MetadataGenerate, clone) if environment
              plan_action(ElasticSearch::ContentViewPuppetEnvironment::IndexContent, id: clone.id)
            end
          end
        end

        private

        # The environment clone clone of the repository is the one
        # visible for the systems in the environment
        def find_or_build_puppet_env(version, environment)
          puppet_env = ::Katello::ContentViewPuppetEnvironment.in_content_view(version.content_view).
              in_environment(environment).scoped(:readonly => false).first
          puppet_env = version.content_view.build_puppet_env(:environment => environment) unless puppet_env
          puppet_env
        end

        def find_or_build_puppet_archive(new_version)
          puppet_env = new_version.archive_puppet_environment
          puppet_env = new_version.content_view.build_puppet_env(:version => new_version) unless puppet_env
          puppet_env
        end
      end
    end
  end
end