# frozen_string_literal: true

RSpec.describe "Add rating item" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) do
    Fabricate(:topic_with_op, category: board_category, title: "Ramen shops near campus")
  end
  fab!(:item_topic) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      title: "Ichiran Ramen Kyoto",
    )
  end

  let(:board_page) { PageObjects::Pages::KuuRatingsBoard.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:image) { file_from_fixtures("logo.png", "images") }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  context "when logged in" do
    before { sign_in(user) }

    it "lets the user submit an item for review" do
      board_page.visit_board(board_topic)
      add_item_modal = board_page.click_add_item

      expect(add_item_modal).to have_board(board_topic)

      add_item_modal.fill_in(name: "Ippudo", image:).submit

      expect(add_item_modal).to be_closed
      expect(toasts).to have_success(I18n.t("js.kuu_ratings.submitted"))

      submission = ReviewableKuuRatingSubmission.sole
      expect(submission).to be_pending
      expect(submission.board_topic_id).to eq(board_topic.id)
      expect(submission.items.map { |item| item["name"] }).to eq(["Ippudo"])
    end

    it "lets the user submit an item on mobile", mobile: true do
      board_page.visit_board(board_topic)
      add_item_modal = board_page.click_add_item.fill_in(name: "Ippudo", image:)
      add_item_modal.submit

      expect(add_item_modal).to be_closed
      expect(toasts).to have_success(I18n.t("js.kuu_ratings.submitted"))
    end

    it "shows the user that the board already has an item with the name" do
      board_page.visit_board(board_topic)
      add_item_modal = board_page.click_add_item.fill_in(name: " ICHIRAN  ramen KYOTO ", image:)
      add_item_modal.submit

      expect(add_item_modal).to have_error(I18n.t("kuu_ratings.errors.name_taken"))
      expect(add_item_modal).to be_open
    end

    it "does not offer to add items to a closed board" do
      board_topic.update!(closed: true)

      board_page.visit_board(board_topic)

      expect(board_page).to have_no_add_item_button
    end
  end

  context "when not logged in" do
    it "does not offer to add items" do
      board_page.visit_board(board_topic)

      expect(board_page).to have_no_add_item_button
    end
  end
end
