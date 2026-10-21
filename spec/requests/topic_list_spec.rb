# frozen_string_literal: true

RSpec.describe "Rating items in topic lists" do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic_with_op, category: board_category) }
  fab!(:item_topic) do
    Fabricate(:kuu_rating_item, category: item_category, board: board_topic, user:)
  end
  fab!(:other_topic) { Fabricate(:topic_with_op, user:) }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def listed_topic_ids
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { |topic| topic["id"] }
  end

  it "leaves items out of the latest list" do
    get "/latest.json"

    expect(listed_topic_ids).to include(board_topic.id)
    expect(listed_topic_ids).not_to include(item_topic.id)
  end

  it "leaves items out of the board category page" do
    get "/c/#{board_category.slug}/#{board_category.id}.json"

    expect(listed_topic_ids).to include(board_topic.id)
    expect(listed_topic_ids).not_to include(item_topic.id)
  end

  it "leaves items out of the item category page" do
    get "/c/#{board_category.slug}/#{item_category.slug}/#{item_category.id}/l/latest.json"

    expect(listed_topic_ids).not_to include(item_topic.id)
  end

  it "leaves items out of the topics a user created" do
    sign_in(user)
    get "/topics/created-by/#{user.username}.json"

    expect(listed_topic_ids).to contain_exactly(other_topic.id)
  end

  it "leaves items out of the suggested topics" do
    get "/t/#{other_topic.id}.json"

    expect(response.status).to eq(200)
    suggested_ids = response.parsed_body["suggested_topics"].map { |topic| topic["id"] }
    expect(suggested_ids).to include(board_topic.id)
    expect(suggested_ids).not_to include(item_topic.id)
  end

  it "still opens items by their link" do
    get "/t/#{item_topic.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["id"]).to eq(item_topic.id)
  end

  context "when the plugin is disabled" do
    before { SiteSetting.kuu_ratings_enabled = false }

    it "lists items as usual" do
      sign_in(user)
      get "/latest.json"
      expect(listed_topic_ids).to include(item_topic.id)

      get "/c/#{board_category.slug}/#{item_category.slug}/#{item_category.id}/l/latest.json"
      expect(listed_topic_ids).to include(item_topic.id)

      get "/topics/created-by/#{user.username}.json"
      expect(listed_topic_ids).to include(item_topic.id)
    end
  end
end
