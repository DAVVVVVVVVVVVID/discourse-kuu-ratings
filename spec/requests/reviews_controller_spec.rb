# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::ReviewsController do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

  let!(:review) do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    kuu_add_review(item_topic)
  end
  let!(:replies) { Array.new(13) { |index| kuu_reply_to(review, raw: "Reply #{index}") } }

  describe "#replies" do
    def get_replies(post, offset: nil)
      get "/kuu-ratings/reviews/#{post.id}/replies.json", params: { offset: }.compact
    end

    def reply_ids
      response.parsed_body["replies"].map { |reply| reply["id"] }
    end

    it "returns the first page of replies in posting order" do
      get_replies(review)

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "root_post_id" => review.id,
        "root_deleted" => false,
        "reply_count" => 13,
        "can_reply" => false,
        "has_more" => true,
      )
      expect(reply_ids).to eq(replies.first(10).map(&:id))
    end

    it "returns the next page from the offset" do
      get_replies(review, offset: 10)

      expect(response.status).to eq(200)
      expect(response.parsed_body["has_more"]).to eq(false)
      expect(reply_ids).to eq(replies.last(3).map(&:id))
    end

    it "says there are no more replies when the page is exactly full" do
      replies.last(3).each(&:trash!)

      get_replies(review)

      expect(response.parsed_body).to include("reply_count" => 10, "has_more" => false)
      expect(reply_ids).to eq(replies.first(10).map(&:id))
    end

    it "leaves out deleted replies" do
      replies.first.trash!

      get_replies(review)

      expect(response.parsed_body["reply_count"]).to eq(12)
      expect(reply_ids).to eq(replies[1..10].map(&:id))
    end

    it "lets a logged in user reply" do
      sign_in(user)

      get_replies(review)

      expect(response.parsed_body["can_reply"]).to eq(true)
    end

    it "still lists the replies of a deleted review" do
      review.trash!
      sign_in(user)

      get_replies(review)

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "root_deleted" => true,
        "can_reply" => false,
        "reply_count" => 13,
      )
      expect(reply_ids).to eq(replies.first(10).map(&:id))
    end

    it "returns a 404 for a reply" do
      get_replies(replies.first)

      expect(response.status).to eq(404)
    end

    it "returns a 404 for the first post of the item" do
      get_replies(item_topic.first_post)

      expect(response.status).to eq(404)
    end

    it "returns a 404 for a post outside the item category" do
      get_replies(Fabricate(:post, topic: Fabricate(:topic_with_op)))

      expect(response.status).to eq(404)
    end

    it "returns a 404 for a post that does not exist" do
      get "/kuu-ratings/reviews/#{Post.maximum(:id) + 1}/replies.json"

      expect(response.status).to eq(404)
    end

    it "returns a 404 when the user cannot see the item" do
      item_category.set_permissions(admins: :full)
      item_category.save!
      sign_in(user)

      get_replies(review)

      expect(response.status).to eq(404)
    end

    it "returns a 400 for a negative offset" do
      get_replies(review, offset: -1)

      expect(response.status).to eq(400)
    end

    it "returns a 404 when the plugin is disabled" do
      SiteSetting.kuu_ratings_enabled = false

      get_replies(review)

      expect(response.status).to eq(404)
    end
  end
end
