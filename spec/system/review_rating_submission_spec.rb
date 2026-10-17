# frozen_string_literal: true

RSpec.describe "Review rating submission" do
  fab!(:admin)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) do
    Fabricate(:topic_with_op, category: board_category, title: "Ramen shops near campus")
  end
  fab!(:board_submission) do
    Fabricate(:kuu_board_submission, title: "Curry shops", names: %w[Coco Go-Go])
  end
  fab!(:item_submission) { Fabricate(:kuu_item_submission, board: board_topic, name: "Ippudo") }

  let(:review_page) { PageObjects::Pages::KuuRatingsReview.new }
  let(:board_page) { PageObjects::Pages::KuuRatingsBoard.new }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    [board_submission, item_submission].each(&:queue_for_review!)
    sign_in(admin)
  end

  it "shows the moderator both kinds of submissions" do
    review_page.visit_queue

    expect(review_page).to have_new_board_submission(
      board_submission,
      title: "Curry shops",
      names: %w[Coco Go-Go],
    )
    expect(review_page).to have_add_item_submission(
      item_submission,
      board: board_topic,
      names: ["Ippudo"],
    )
  end

  it "publishes a new board with its items once the moderator approves it" do
    review_page.visit_queue
    review_page.approve(board_submission)

    expect(review_page).to have_status(board_submission, "approved")

    board = Topic.find_by(category: board_category, title: "Curry shops")
    board_page.visit_board(board)

    expect(board_page).to have_unscored_item(Topic.find_by(title: "Coco"))
    expect(board_page).to have_unscored_item(Topic.find_by(title: "Go-Go"))
  end

  it "publishes an added item once the moderator approves it" do
    review_page.visit_queue
    review_page.approve(item_submission)

    expect(review_page).to have_status(item_submission, "approved")

    board_page.visit_board(board_topic)

    expect(board_page).to have_unscored_item(Topic.find_by(title: "Ippudo"))
  end

  it "lets the moderator reject a submission" do
    review_page.visit_queue
    review_page.reject(board_submission)

    expect(review_page).to have_status(board_submission, "rejected")
    expect(Topic.where(title: "Curry shops")).to be_empty
  end

  it "lets the moderator review submissions on mobile", mobile: true do
    review_page.visit_queue

    expect(review_page).to have_add_item_submission(
      item_submission,
      board: board_topic,
      names: ["Ippudo"],
    )

    review_page.approve(item_submission)

    expect(review_page).to have_status(item_submission, "approved")
  end
end
