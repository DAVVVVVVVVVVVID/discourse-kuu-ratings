# frozen_string_literal: true

RSpec.describe "Scores next to posts in rating items" do
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
  fab!(:review) { Fabricate(:kuu_review, item_topic:, score: 10) }
  fab!(:replier_score) { Fabricate(:kuu_rating_score, item_topic:, score: 6) }
  fab!(:scored_reply) do
    Fabricate(
      :post,
      topic: item_topic,
      user: replier_score.user,
      reply_to_post_number: review.post.post_number,
    )
  end
  fab!(:unscored_reply) do
    Fabricate(:post, topic: item_topic, reply_to_post_number: review.post.post_number)
  end

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def scores_in_topic(topic)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    response.parsed_body["post_stream"]["posts"].to_h { |post| [post["id"], post["kuu_score"]] }
  end

  it "shows each author's score on every post of the item" do
    expect(scores_in_topic(item_topic)).to eq(
      item_topic.first_post.id => nil,
      review.post_id => 10,
      scored_reply.id => 6,
      unscored_reply.id => nil,
    )
  end

  it "shows the author's score on a single post" do
    get "/posts/#{scored_reply.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["kuu_score"]).to eq(6)
  end

  context "with a topic outside the item category" do
    fab!(:other_topic, :topic_with_op)

    it "does not add the score" do
      get "/t/#{other_topic.id}.json"

      expect(response.parsed_body["post_stream"]["posts"]).to all(exclude("kuu_score"))
    end
  end

  context "when the plugin is disabled" do
    before { SiteSetting.kuu_ratings_enabled = false }

    it "does not add the score" do
      get "/t/#{item_topic.id}.json"

      expect(response.parsed_body["post_stream"]["posts"]).to all(exclude("kuu_score"))
    end
  end
end
