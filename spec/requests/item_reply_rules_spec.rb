# frozen_string_literal: true

RSpec.describe "Replies in rating items" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
  fab!(:review_post) { Fabricate(:post, topic: item_topic) }

  let(:raw) { "I agree, the broth is really rich here." }
  let(:reply_params) { { topic_id: item_topic.id, raw: } }
  let(:error_message) { I18n.t("kuu_ratings.errors.reply_to_item_not_allowed") }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    sign_in(user)
  end

  def expect_rejected
    expect { post "/posts.json", params: reply_params }.not_to change { Post.count }
    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to contain_exactly(error_message)
  end

  it "rejects a reply to the item itself" do
    expect_rejected
  end

  it "rejects a reply to the first post" do
    reply_params[:reply_to_post_number] = 1
    expect_rejected
  end

  it "rejects a reply to a post that does not exist" do
    reply_params[:reply_to_post_number] = 99
    expect_rejected
  end

  it "rejects a reply to a deleted post" do
    review_post.trash!
    reply_params[:reply_to_post_number] = review_post.post_number
    expect_rejected
  end

  it "applies to staff too" do
    sign_in(Fabricate(:admin))
    expect_rejected
  end

  it "allows a reply to a short review" do
    reply_params[:reply_to_post_number] = review_post.post_number

    post "/posts.json", params: reply_params

    expect(response.status).to eq(200)
    expect(Post.last).to have_attributes(
      topic_id: item_topic.id,
      reply_to_post_number: review_post.post_number,
    )
  end

  it "allows a reply to a reply" do
    reply = Fabricate(:post, topic: item_topic, reply_to_post_number: review_post.post_number)
    reply_params[:reply_to_post_number] = reply.post_number

    post "/posts.json", params: reply_params

    expect(response.status).to eq(200)
  end

  it "still allows posting a short review through the score endpoint" do
    post "/kuu-ratings/items/#{item_topic.id}/score.json", params: { stars: 4, comment: "好吃" }

    expect(response.status).to eq(201)
    expect(item_topic.posts.last).to have_attributes(raw: "好吃", reply_to_post_number: nil)
  end

  it "does not affect creating a new topic in the item category" do
    post "/posts.json",
         params: {
           title: "Another ramen shop near campus",
           raw: "Thin noodles and light broth, worth a visit.",
           category: item_category.id,
         }

    expect(response.status).to eq(200)
  end

  it "does not affect replies in other categories" do
    other_topic = Fabricate(:topic_with_op)

    post "/posts.json", params: { topic_id: other_topic.id, raw: }

    expect(response.status).to eq(200)
  end

  it "does not apply when the plugin is disabled" do
    SiteSetting.kuu_ratings_enabled = false

    post "/posts.json", params: reply_params

    expect(response.status).to eq(200)
  end
end
