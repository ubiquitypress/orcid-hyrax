# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hyrax::Actors::Orcid::PublishWorkActor do
  subject(:actor) { described_class.new(next_actor) }
  let(:ability) { Ability.new(user) }
  let(:env) { Hyrax::Actors::Environment.new(work, ability, {}) }
  let(:next_actor) { Hyrax::Actors::Terminator.new }
  let(:user) { create(:user, :with_orcid_identity) }
  let(:model_class) { GenericWork }
  let(:work) { model_class.create(work_attributes) }
  let(:work_attributes) do
    {
      "title" => ["Moomin"],
      "creator" => [
        [{
          "creator_name" => "Joan Smith",
          "creator_orcid" => orcid_id
        }].to_json
      ],
      "keyword" => ["a keyword"],
      "rights_statement" => ["http://rightsstatements.org/vocab/InC-OW-EU/1.0/"]
    }
  end
  let(:orcid_id) { user.orcid_identity.orcid_id }

  before do
    work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

    allow(Flipflop).to receive(:enabled?).and_call_original
    allow(Flipflop).to receive(:enabled?).with(:orcid_identities).and_return(true)

    ActiveJob::Base.queue_adapter = :test
  end

  describe "#create" do
    context "when orcid_identities is enabled" do
      it "enqueues a job" do
        expect { actor.create(env) }.to have_enqueued_job(Hyrax::Orcid::IdentityStrategyDelegatorJob)
          .with(work)
          .on_queue(Hyrax.config.ingest_queue_name)
      end
    end

    context "when orcid_identities is disabled" do
      before do
        allow(Flipflop).to receive(:enabled?).with(:orcid_identities).and_return(false)
      end

      it "does not enqueue a job" do
        expect { actor.create(env) }.not_to have_enqueued_job(Hyrax::Orcid::IdentityStrategyDelegatorJob)
      end
    end

    context "when the work is private" do
      before do
        work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      end

      it "does not enqueue a job" do
        expect { actor.create(env) }.not_to have_enqueued_job(Hyrax::Orcid::IdentityStrategyDelegatorJob)
      end
    end
  end

  describe "#update" do
    context "when orcid_identities is enabled" do
      it "enqueues a job" do
        expect { actor.update(env) }.to have_enqueued_job(Hyrax::Orcid::IdentityStrategyDelegatorJob)
          .with(work)
          .on_queue(Hyrax.config.ingest_queue_name)
      end
    end

    context "when orcid_identities is disabled" do
      before do
        allow(Flipflop).to receive(:enabled?).with(:orcid_identities).and_return(false)
      end

      it "does not enqueue a job" do
        expect { actor.update(env) }.not_to have_enqueued_job(Hyrax::Orcid::IdentityStrategyDelegatorJob)
      end
    end

    context "when the work is private" do
      before do
        work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      end

      it "does not enqueue a job" do
        expect { actor.update(env) }.not_to have_enqueued_job(Hyrax::Orcid::IdentityStrategyDelegatorJob)
      end
    end
  end

  describe "visible?" do
    context "when the work is public" do
      it "is true" do
        expect(actor.send(:visible?, env)).to be_truthy
      end
    end

    context "when the work is private" do
      before do
        work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      end

      it "is false" do
        expect(actor.send(:visible?, env)).to be_falsey
      end
    end

    context "when the work is restricted to the institution" do
      before do
        work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
      end

      it "is false" do
        expect(actor.send(:visible?, env)).to be_falsey
      end
    end
  end
end
