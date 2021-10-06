# frozen_string_literal: true

require 'rails/all'

module Hyrax
  module Orcid
    class Engine < Rails::Engine
      isolate_namespace Hyrax::Orcid

      config.before_initialize do
        Rails.application.configure { config.eager_load = true } if Rails.env.development?

        Rails.application.routes.prepend do
          mount Hyrax::Orcid::Engine => "/"
        end
      end

      # Allow flipflop to load config/features.rb from the Hyrax gem:
      initializer "configure" do
        Flipflop::FeatureLoader.current.append(self)
      end

      # rubocop:disable Metrics/MethodLength
      def self.dynamically_include_mixins
        ::User.include Hyrax::Orcid::UserBehavior

        # Add any required helpers, for routes, api metadata etc
        Hyrax::HyraxHelperBehavior.include Hyrax::Orcid::HelperBehavior

        # Add the JSON processing code to the default presenter
        presenter_behavior = Hyrax::Orcid.configuration.presenter_behavior
        Hyrax::WorkShowPresenter.prepend presenter_behavior.constantize if presenter_behavior.present?

        # Allow the JSON fields to be indexed individually
        Hyrax::WorkIndexer.include Hyrax::Orcid::WorkIndexerBehavior

        # All work types and their forms will require the following concerns to be included

        if (work_types = Hyrax::Orcid.configuration.work_types).present?
          work_types.each do |work_type|
            "Hyrax::#{work_type}Form".constantize.include Hyrax::Orcid::WorkFormBehavior
            work_type.constantize.include Hyrax::Orcid::WorkBehavior
          end
        end

        # Insert our custom reader and writer to process works ready before publishing
        Bolognese::Metadata.prepend Bolognese::Writers::Orcid::XmlWriter
        Bolognese::Metadata.prepend Bolognese::Readers::Orcid::HyraxWorkReader

        # Because the Hyrax::ModelActor does not call next_actor to continue the chain,
        # for destroy requests, we require a new actor
        actors = [Hyrax::Actors::ModelActor, Hyrax::Actors::Orcid::UnpublishWorkActor]
        Hyrax::CurationConcern.actor_factory.insert_before(*actors)

        # Insert the publish actor at the end of the chain so we only publish a fully processed work
        Hyrax::CurationConcern.actor_factory.use Hyrax::Actors::Orcid::PublishWorkActor

        # Insert an extra step in the Blacklight rendering pipeline where our JSON can be parsed
        operation = Hyrax::Orcid.configuration.blacklight_pipeline_actor
        ::Blacklight::Rendering::Pipeline.operations.insert(1, operation.constantize) if operation.present?

        # Insert our JSON actor before the Model is saved
        actor = Hyrax::Orcid.configuration.hyrax_json_actor
        Hyrax::CurationConcern.actor_factory.insert_before Hyrax::Actors::ModelActor, actor.constantize if actor.present?

        # Prepend our views so they have precedence
        ActionController::Base.prepend_view_path(paths["app/views"].existent)

        # Append our locales so they have precedence
        I18n.load_path += Dir[Hyrax::Orcid::Engine.root.join("config", "locales", "*.{rb,yml}")]
      end
      # rubocop:enable Metrics/MethodLength

      if Rails.env.development?
        config.to_prepare { Hyrax::Orcid::Engine.dynamically_include_mixins }
      else
        config.after_initialize { Hyrax::Orcid::Engine.dynamically_include_mixins }
      end
    end
  end
end
