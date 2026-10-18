# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::ReviewThreads do
  fab!(:admin)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

  let(:review) { kuu_add_review(item_topic) }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def root_of(post)
    PostCustomField.find_by(post_id: post.id, name: described_class::ROOT_FIELD)&.value&.to_i
  end

  # 通过 :post_created 和 :approved_post 两个事件调用
  describe ".assign_root" do
    it "records the review a reply belongs to" do
      reply = kuu_reply_to(review)

      expect(root_of(reply)).to eq(review.id)
    end

    it "keeps replies to replies in the thread of the top review" do
      reply = kuu_reply_to(review)
      reply_to_reply = kuu_reply_to(reply)
      deeper_reply = kuu_reply_to(reply_to_reply)

      expect([root_of(reply_to_reply), root_of(deeper_reply)]).to eq([review.id, review.id])
    end

    it "does not record a root for a review or a reply to the first post" do
      reply_to_first_post = kuu_reply_to(item_topic.first_post)

      expect([root_of(review), root_of(reply_to_first_post)]).to eq([nil, nil])
    end

    it "does not record a root outside the item category" do
      other_post = Fabricate(:post)
      reply = kuu_reply_to(other_post)

      expect(root_of(reply)).to be_nil
    end

    it "does not record a root when the plugin is disabled" do
      review
      SiteSetting.kuu_ratings_enabled = false

      reply = kuu_reply_to(review)

      expect(root_of(reply)).to be_nil
    end

    it "records the root of a reply that was created by approving a queued post" do
      reply = kuu_reply_to(review)
      queued =
        Fabricate(
          :reviewable_queued_post,
          topic: item_topic,
          payload: {
            raw: "Agreed, queued",
            reply_to_post_number: reply.post_number,
          },
        )

      result = queued.perform(admin, :approve_post)

      expect(result.created_post.reply_to_post_number).to eq(reply.post_number)
      expect(root_of(result.created_post)).to eq(review.id)
    end
  end
end
