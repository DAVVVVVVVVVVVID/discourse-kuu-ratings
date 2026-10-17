# frozen_string_literal: true

# 走 core 真实的删帖、删用户、合并用户流程，确认事件监听把打分清理干净
RSpec.describe "Rating score cleanup" do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
  fab!(:other_item) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
  fab!(:review_post) { Fabricate(:post, topic: item_topic, user:) }
  fab!(:review_score) do
    Fabricate(:kuu_rating_score, item_topic:, user:, post: review_post, score: 10)
  end
  fab!(:plain_score) { Fabricate(:kuu_rating_score, item_topic: other_item, user:, score: 6) }
  fab!(:other_score) { Fabricate(:kuu_rating_score, item_topic:, user: other_user, score: 4) }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def score_ids
    DiscourseKuuRatings::RatingScore.ids
  end

  describe "deleting a short review" do
    it "removes the score right away when the author deletes it, although the post is only marked for deletion" do
      expect { PostDestroyer.new(user, review_post).destroy }.to change { score_ids }.to(
        contain_exactly(plain_score.id, other_score.id),
      )

      expect(review_post.reload).to have_attributes(user_deleted: true, deleted_at: nil)
      expect(item_topic.reload.custom_fields).to include(
        "kuu_score_count" => 1,
        "kuu_score_avg" => "4.0",
      )
    end

    it "removes the score when an admin deletes someone else's review" do
      expect { PostDestroyer.new(admin, review_post).destroy }.to change { score_ids }.to(
        contain_exactly(plain_score.id, other_score.id),
      )

      expect(review_post.reload).to be_trashed
    end

    it "keeps the score when a reply to the review is deleted" do
      reply =
        Fabricate(
          :post,
          topic: item_topic,
          user: other_user,
          reply_to_post_number: review_post.post_number,
        )

      expect { PostDestroyer.new(other_user, reply).destroy }.not_to change { score_ids }
    end

    it "keeps the score when the plugin is disabled" do
      SiteSetting.kuu_ratings_enabled = false

      expect { PostDestroyer.new(admin, review_post).destroy }.not_to change { score_ids }
    end
  end

  describe "deleting my score" do
    it "removes the score once and keeps the stats right" do
      result =
        DiscourseKuuRatings::RatingScore::Destroy.call(
          params: {
            item_topic_id: item_topic.id,
          },
          guardian: user.guardian,
        )

      expect(result).to run_successfully
      expect(score_ids).to contain_exactly(plain_score.id, other_score.id)
      expect(review_post.reload).to be_trashed
      expect(item_topic.reload.custom_fields).to include(
        "kuu_score_count" => 1,
        "kuu_score_avg" => "4.0",
      )
    end
  end

  describe "deleting a user" do
    it "removes the user's scores with and without a review and refreshes every item" do
      UserDestroyer.new(admin).destroy(user, delete_posts: true)

      expect(score_ids).to contain_exactly(other_score.id)
      expect(item_topic.reload.custom_fields).to include(
        "kuu_score_count" => 1,
        "kuu_score_avg" => "4.0",
      )
      expect(other_item.reload.custom_fields).to include("kuu_score_count" => 0)
      expect(other_item.custom_fields).not_to have_key("kuu_score_avg")
    end
  end

  describe "merging users" do
    fab!(:target_user, :user)

    it "removes all scores of the source user, even those whose review moved to the target user (known limitation)" do
      UserMerger.new(user, target_user, admin).merge!

      expect(score_ids).to contain_exactly(other_score.id)
      expect(review_post.reload).to have_attributes(user_id: target_user.id, deleted_at: nil)
    end
  end
end
