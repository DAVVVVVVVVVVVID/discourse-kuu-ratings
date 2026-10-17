# frozen_string_literal: true

RSpec.describe "Rating items in topic lists" do
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def listed_topic_ids
    response.parsed_body["topic_list"]["topics"].map { |topic| topic["id"] }
  end

  it "leaves items out of the latest list" do
    get "/latest.json"

    expect(response.status).to eq(200)
    expect(listed_topic_ids).to include(board_topic.id)
    expect(listed_topic_ids).not_to include(item_topic.id)
  end

  it "lists items on the item category page" do
    get "/c/#{board_category.slug}/#{item_category.slug}/#{item_category.id}/l/latest.json"

    expect(response.status).to eq(200)
    expect(listed_topic_ids).to include(item_topic.id)
  end
end
