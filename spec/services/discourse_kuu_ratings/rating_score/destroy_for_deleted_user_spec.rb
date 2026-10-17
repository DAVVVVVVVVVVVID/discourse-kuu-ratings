# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore::DestroyForDeletedUser do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:user_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:item_topic, :topic_with_op)
    fab!(:other_item, :topic_with_op)
    fab!(:deleted_item) { Fabricate(:topic_with_op, deleted_at: 1.day.ago) }
    fab!(:review_post) { Fabricate(:post, topic: item_topic, user:) }
    fab!(:review_score) do
      Fabricate(:kuu_rating_score, item_topic:, user:, post: review_post, score: 10)
    end
    fab!(:plain_score) { Fabricate(:kuu_rating_score, item_topic: other_item, user:, score: 6) }
    fab!(:deleted_item_score) do
      Fabricate(:kuu_rating_score, item_topic: deleted_item, user:, score: 8)
    end
    fab!(:other_score) { Fabricate(:kuu_rating_score, item_topic:, score: 4) }
    fab!(:other_deleted_item_score) do
      Fabricate(:kuu_rating_score, item_topic: deleted_item, score: 2)
    end

    let(:params) { { user_id: } }
    let(:dependencies) { {} }
    let(:user_id) { user.id }

    context "when the contract is invalid" do
      let(:user_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the user has no scores" do
      fab!(:user)

      it { is_expected.to fail_to_find_a_model(:rating_scores) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys all scores of the user and keeps the others" do
        expect { result }.to change { DiscourseKuuRatings::RatingScore.ids }.to(
          contain_exactly(other_score.id, other_deleted_item_score.id),
        )
      end

      it "refreshes the stats of every affected item" do
        result

        expect(item_topic.reload.custom_fields).to include(
          "kuu_score_count" => 1,
          "kuu_score_avg" => "4.0",
        )
        expect(other_item.reload.custom_fields).to include("kuu_score_count" => 0)
        expect(other_item.custom_fields).not_to have_key("kuu_score_avg")
        expect(deleted_item.reload.custom_fields).to include(
          "kuu_score_count" => 1,
          "kuu_score_avg" => "2.0",
        )
      end
    end
  end
end
