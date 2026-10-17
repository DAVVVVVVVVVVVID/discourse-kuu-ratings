# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore::DestroyForDeletedPost do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:item_topic, :topic_with_op)
    fab!(:review_post) { Fabricate(:post, topic: item_topic) }
    fab!(:rating_score) do
      Fabricate(
        :kuu_rating_score,
        item_topic:,
        user: review_post.user,
        post: review_post,
        score: 10,
      )
    end
    fab!(:other_score) { Fabricate(:kuu_rating_score, item_topic:, score: 4) }

    let(:params) { { post_id: } }
    let(:dependencies) { {} }
    let(:post_id) { review_post.id }

    context "when the contract is invalid" do
      let(:post_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the post is not a short review" do
      let(:post_id) { item_topic.first_post.id }

      it { is_expected.to fail_to_find_a_model(:rating_score) }
    end

    context "when the item has been deleted" do
      before { item_topic.trash! }

      it { is_expected.to run_successfully }

      it "refreshes the item stats" do
        result

        expect(item_topic.reload.custom_fields).to include(
          "kuu_score_count" => 1,
          "kuu_score_avg" => "4.0",
        )
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys only the score of the post" do
        expect { result }.to change { DiscourseKuuRatings::RatingScore.ids }.to(
          contain_exactly(other_score.id),
        )
      end

      it "refreshes the item stats" do
        result

        expect(item_topic.reload.custom_fields).to include(
          "kuu_score_count" => 1,
          "kuu_score_avg" => "4.0",
        )
      end
    end
  end
end
