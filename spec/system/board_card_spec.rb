# frozen_string_literal: true

RSpec.describe "Rating board cards in topic lists" do
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) do
    Fabricate(:topic_with_op, category: board_category, title: "Ramen shops near campus")
  end
  fab!(:other_topic) { Fabricate(:topic_with_op, title: "Where to buy a used bike") }
  # 卡片顺序：popular（2 人）> top（1 人 10 分）> plain（1 人 4 分）> unrated（没人打分，比 extra 新）；
  # extra 排第 5，不显示
  fab!(:popular_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Ippudo Ramen Kyoto",
      scores: [6, 8],
      created_at: 5.days.ago,
      image_upload: Fabricate(:image_upload),
    )
  end
  fab!(:top_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Ichiran Ramen Kyoto",
      scores: [10],
      created_at: 4.days.ago,
    )
  end
  fab!(:plain_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Menya Inoichi Kyoto",
      scores: [4],
      created_at: 3.days.ago,
    )
  end
  fab!(:extra_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Tenkaippin Kyoto",
      created_at: 2.days.ago,
    )
  end
  fab!(:unrated_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Kirakutei Kyoto",
      created_at: 1.day.ago,
    )
  end

  let(:card) { PageObjects::Components::KuuRatingsBoardCard.new(board_topic) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:item_page) { PageObjects::Pages::KuuRatingsItem.new }
  let(:board_page) { PageObjects::Pages::KuuRatingsBoard.new }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  # 打开帖子后 Discourse 会按当前读到的帖子在网址后面补上帖子编号（/t/slug/id/2），时机不固定
  def topic_path(topic)
    %r{\A#{Regexp.escape(topic.relative_url)}(/\d+)?\z}
  end

  def image_file_name(url)
    File.basename(url)
  end

  def expect_card
    expect(card).to be_shown
    expect(card).to have_items_in_order(popular_item, top_item, plain_item, unrated_item)
    expect(card).to have_item(popular_item, score: "7.0")
    expect(card).to have_item(top_item, score: "10.0")
    expect(card).to have_item(plain_item, score: "4.0")
    expect(card).to have_unscored_item(unrated_item)
    expect(card).to have_item_image(
      popular_item,
      src: image_file_name(popular_item.reload.image_upload.url),
    )
    expect(card).to have_more_link
  end

  it "shows boards as cards on the latest list" do
    visit("/latest")

    expect_card
    expect(PageObjects::Components::KuuRatingsBoardCard.new(other_topic)).to be_not_shown
  end

  it "shows boards as cards on the board category page" do
    visit("/c/#{board_category.slug}/#{board_category.id}")

    expect_card
  end

  it "shows an icon for items without an image" do
    visit("/latest")

    expect(card).to have_item_image_icon(unrated_item)
  end

  context "with a placeholder image" do
    fab!(:placeholder, :image_upload)

    before { SiteSetting.kuu_ratings_placeholder_image = placeholder }

    it "shows the placeholder for items without an image" do
      visit("/latest")

      expect(card).to have_item_image(unrated_item, src: image_file_name(placeholder.reload.url))
      expect(card).to have_item_image(
        popular_item,
        src: image_file_name(popular_item.reload.image_upload.url),
      )
    end
  end

  it "takes the user to an item when they click it" do
    visit("/latest")
    card.click_item(top_item)

    expect(page).to have_current_path(topic_path(top_item))
    expect(item_page).to have_board_link(board_topic)
  end

  it "takes the user to the board when they click the more link" do
    visit("/latest")
    card.click_more

    expect(page).to have_current_path(topic_path(board_topic))
    expect(board_page).to have_items_in_order(
      top_item,
      popular_item,
      plain_item,
      unrated_item,
      extra_item,
    )
  end

  it "takes the user to the board when they click the title" do
    visit("/latest")
    card.click_title

    expect(page).to have_current_path(topic_path(board_topic))
    expect(board_page).to have_hidden_first_post
  end

  it "keeps the items out of the latest list" do
    visit("/latest")

    expect(topic_list).to have_topic(board_topic)
    expect(topic_list).to have_topic(other_topic)
    [popular_item, top_item, plain_item, extra_item, unrated_item].each do |item|
      expect(topic_list).to have_no_topic(item)
    end
  end

  it "shows the cards on mobile", mobile: true do
    visit("/latest")

    expect(card).to be_shown
    expect(card).to have_items_in_order(popular_item, top_item, plain_item, unrated_item)
    expect(card).to have_more_link
    expect(card).to be_scrolls_sideways_within_page
  end
end
