# frozen_string_literal: true

RSpec.describe "Create rating board" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }

  let(:choice_modal) { PageObjects::Modals::KuuRatingsNewTopicChoice.new }
  let(:board_modal) { PageObjects::Modals::KuuRatingsNewBoard.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:image) { file_from_fixtures("logo.png", "images") }
  let(:other_image) { file_from_fixtures("logo.jpg", "images") }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    sign_in(user)
  end

  def open_board_form
    visit("/latest")
    category_page.new_topic_button.click
    choice_modal.choose_board
    expect(board_modal).to be_open
  end

  describe "choosing what to post" do
    it "lets the user start a regular topic" do
      visit("/latest")
      category_page.new_topic_button.click

      expect(choice_modal).to be_open

      choice_modal.choose_topic

      expect(choice_modal).to be_closed
      expect(composer).to be_opened

      composer.fill_title("This is a regular topic")
      composer.fill_content("This is a long enough sentence.")
      composer.create

      expect(page).to have_css("#topic-title", text: "This is a regular topic")
    end

    it "lets the user start a rating board" do
      visit("/latest")
      category_page.new_topic_button.click
      choice_modal.choose_board

      expect(board_modal).to be_open
      expect(choice_modal).to be_closed
    end

    it "opens the rating board form straight from the reply-only board category" do
      board_category.set_permissions(everyone: :create_post)
      board_category.save!

      visit(board_category.url)
      category_page.new_topic_button.click

      expect(board_modal).to be_open
      expect(choice_modal).to be_closed
    end

    it "lets the user choose on mobile", mobile: true do
      visit("/latest")
      category_page.new_topic_button.click
      choice_modal.choose_board

      expect(board_modal).to be_open
    end
  end

  describe "the rating board form" do
    it "lets the user add up to 20 items and remove extra ones" do
      open_board_form

      expect(board_modal).to have_items(count: 2)
      expect(board_modal).to have_no_remove_buttons

      board_modal.click_add_item

      expect(board_modal).to have_items(count: 3)
      expect(board_modal).to have_remove_buttons(count: 3)

      board_modal.item(2).remove

      expect(board_modal).to have_items(count: 2)
      expect(board_modal).to have_no_remove_buttons

      18.times { board_modal.click_add_item }

      expect(board_modal).to have_items(count: 20)
      expect(board_modal).to have_no_add_item_button
    end

    it "shows the user what is missing or duplicated" do
      open_board_form

      board_modal.fill_in_item(0, name: "Ichiran").fill_in_item(1, name: "  ichiran ")
      board_modal.submit

      required = I18n.t("js.form_kit.errors.required")
      expect(board_modal).to have_title_error(required)
      expect(board_modal.item(0)).to have_image_error(required)
      expect(board_modal.item(1)).to have_image_error(required)
      expect(board_modal.item(1)).to have_name_error(
        I18n.t("js.kuu_ratings.board_form.duplicate_name"),
      )
      expect(board_modal).to be_open
    end

    it "submits the board for review" do
      open_board_form

      board_modal
        .fill_in_title("Ramen shops")
        .fill_in_item(0, name: "Ichiran", image:)
        .fill_in_item(1, name: "Ippudo", image: other_image)
      board_modal.submit

      expect(board_modal).to be_closed
      expect(toasts).to have_success(I18n.t("js.kuu_ratings.submitted"))

      submission = ReviewableKuuRatingSubmission.sole
      expect(submission).to be_pending
      expect(submission.target_created_by).to eq(user)
      expect(submission.board_title).to eq("Ramen shops")
      expect(submission.items.map { |item| item["name"] }).to eq(%w[Ichiran Ippudo])
      expect(
        Upload.where(id: submission.upload_ids, user:).pluck(:original_filename),
      ).to contain_exactly(end_with("logo.png"), end_with("logo.jpg"))
    end

    it "submits the board for review on mobile", mobile: true do
      open_board_form

      board_modal
        .fill_in_title("Ramen shops")
        .fill_in_item(0, name: "Ichiran", image:)
        .fill_in_item(1, name: "Ippudo", image:)
      board_modal.submit

      expect(board_modal).to be_closed
      expect(toasts).to have_success(I18n.t("js.kuu_ratings.submitted"))
      expect(ReviewableKuuRatingSubmission.pending.count).to eq(1)
    end

    it "shows the server's error at the top of the form" do
      Fabricate(:watched_word, word: "spam", action: WatchedWord.actions[:block])
      open_board_form

      board_modal
        .fill_in_title("spam shops")
        .fill_in_item(0, name: "Ichiran", image:)
        .fill_in_item(1, name: "Ippudo", image:)
      board_modal.submit

      expect(board_modal).to have_error(I18n.t("contains_blocked_word", word: "spam"))
      expect(board_modal).to be_open
      expect(ReviewableKuuRatingSubmission.count).to eq(0)
    end
  end
end
