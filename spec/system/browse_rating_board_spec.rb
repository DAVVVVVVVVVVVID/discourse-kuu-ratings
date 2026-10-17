# frozen_string_literal: true

RSpec.describe "Browse rating board" do
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) do
    Fabricate(:topic_with_op, category: board_category, title: "Ramen shops near campus")
  end
  # 按分数：top、popular、fresh；按人数：popular、top、fresh；按最新：fresh、popular、top
  fab!(:top_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Ichiran Ramen Kyoto",
      created_at: 3.days.ago,
    )
  end
  fab!(:popular_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Ippudo Ramen Kyoto",
      created_at: 2.days.ago,
      scores: [4, 6],
    )
  end
  fab!(:fresh_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Menya Inoichi Kyoto",
      created_at: 1.day.ago,
    )
  end
  fab!(:reviewer, :user)
  fab!(:liked_review) do
    Fabricate(
      :kuu_review,
      item_topic: top_item,
      user: reviewer,
      score: 10,
      post:
        Fabricate(
          :post,
          topic: top_item,
          user: reviewer,
          raw: "The broth is rich and the noodles are firm",
          like_count: 3,
        ),
    )
  end

  let(:board_page) { PageObjects::Pages::KuuRatingsBoard.new }
  let(:item_page) { PageObjects::Pages::KuuRatingsItem.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    DiscourseKuuRatings::RatingScore.refresh_item_stats(top_item)
  end

  it "shows the items of the board instead of its first post" do
    board_page.visit_board(board_topic)

    expect(board_page).to have_hidden_first_post
    expect(board_page).to have_item(top_item, score: "10.0", count: 1)
    expect(board_page).to have_hot_review(top_item, liked_review)
    expect(board_page).to have_item(popular_item, score: "5.0", count: 2)
    expect(board_page).to have_no_hot_review(popular_item)
    expect(board_page).to have_unscored_item(fresh_item)
  end

  it "lets the user sort the items" do
    board_page.visit_board(board_topic)

    expect(board_page).to have_items_in_order(top_item, popular_item, fresh_item)

    board_page.sort_by("count")

    expect(board_page).to have_items_in_order(popular_item, top_item, fresh_item)

    board_page.sort_by("latest")

    expect(board_page).to have_items_in_order(fresh_item, popular_item, top_item)

    board_page.sort_by("score")

    expect(board_page).to have_items_in_order(top_item, popular_item, fresh_item)
  end

  it "takes the user to an item when they click it" do
    board_page.visit_board(board_topic)
    board_page.click_item(popular_item)

    expect(page).to have_current_path(popular_item.relative_url)
    expect(item_page).to have_board_link(board_topic)
  end

  it "shows the items on mobile", mobile: true do
    board_page.visit_board(board_topic)

    expect(board_page).to have_hidden_first_post
    expect(board_page).to have_item(top_item, score: "10.0", count: 1)
    expect(board_page).to have_hot_review(top_item, liked_review)

    board_page.click_item(top_item)

    expect(page).to have_current_path(top_item.relative_url)
  end

  it "keeps the items out of the latest list" do
    visit("/latest")

    expect(topic_list).to have_topic(board_topic)
    expect(topic_list).to have_no_topic(top_item)
  end
end
