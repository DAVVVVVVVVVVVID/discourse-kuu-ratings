# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:item_topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
    fab!(:comment_post) { Fabricate(:post, topic: item_topic, user:) }
    fab!(:rating_score) { Fabricate(:kuu_rating_score, item_topic:, user:, post: comment_post) }
    fab!(:other_score) { Fabricate(:kuu_rating_score, item_topic:, score: 4) }

    let(:params) { { item_topic_id: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:item_topic_id) { item_topic.id }

    before do
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:item_topic_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the user has not scored the item" do
      fab!(:user)

      it { is_expected.to fail_to_find_a_model(:rating_score) }

      it "leaves other users' scores alone" do
        expect { result }.not_to change { DiscourseKuuRatings::RatingScore.count }
      end
    end

    context "without a comment" do
      fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
      fab!(:rating_score) { Fabricate(:kuu_rating_score, item_topic:, user:) }

      it { is_expected.to run_successfully }

      it "destroys the score" do
        expect { result }.to change {
          DiscourseKuuRatings::RatingScore.exists?(rating_score.id)
        }.from(true).to(false)
      end
    end

    context "when the item has been deleted" do
      before { item_topic.trash! }

      it { is_expected.to run_successfully }

      it "destroys the score" do
        expect { result }.to change {
          DiscourseKuuRatings::RatingScore.exists?(rating_score.id)
        }.from(true).to(false)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys the score" do
        expect { result }.to change {
          DiscourseKuuRatings::RatingScore.exists?(rating_score.id)
        }.from(true).to(false)
      end

      it "deletes the comment post right away" do
        result

        expect(comment_post.reload).to be_trashed
      end

      it "refreshes the item stats" do
        result

        expect(item_topic.reload.custom_fields).to include(
          "kuu_score_count" => 1,
          "kuu_score_avg" => "4.0",
        )
      end

      it "lets the user score the item again" do
        result

        expect(
          DiscourseKuuRatings::RatingScore::Create.call(
            params: {
              item_topic_id:,
              stars: 5,
              comment: "再来一次",
            },
            guardian: user.guardian,
          ),
        ).to run_successfully
      end
    end
  end
end
