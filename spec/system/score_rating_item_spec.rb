# frozen_string_literal: true

RSpec.describe "Score rating item" do
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
      scores: [10, 6],
    )
  end

  let(:item_page) { PageObjects::Pages::KuuRatingsItem.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def add_review(user:, score:, comment:, like_count: 0)
    result =
      DiscourseKuuRatings::RatingScore::Create.call(
        params: {
          item_topic_id: item_topic.id,
          stars: score / 2,
          comment:,
        },
        guardian: user.guardian,
      )
    result.comment_post.update!(like_count:)
    result.rating_score
  end

  context "when logged in" do
    before { sign_in(user) }

    it "shows the user the summary of the item instead of its first post" do
      item_page.visit_item(item_topic)

      expect(item_page).to have_hidden_first_post
      expect(item_page).to have_board_link(board_topic)
      expect(item_page).to have_summary(score: "8.0", count: 2)
      expect(item_page).to have_star_count(stars: 5, count: 1)
      expect(item_page).to have_star_count(stars: 4, count: 0)
      expect(item_page).to have_star_count(stars: 3, count: 1)
    end

    it "lets the user score the item with a review" do
      item_page.visit_item(item_topic)
      item_page.pick_stars(4).fill_in_comment("Rich broth, firm noodles").submit_score

      expect(item_page).to have_my_score(8)
      expect(item_page).to have_summary(score: "8.0", count: 3)
      expect(item_page).to have_star_count(stars: 4, count: 1)
      expect(item_page).to have_review_post(user, "Rich broth, firm noodles", score: 8)

      page.refresh

      expect(item_page).to have_my_score(8)
      expect(item_page).to have_review_post(user, "Rich broth, firm noodles", score: 8)
    end

    it "asks the user for a review of at least 2 characters before scoring" do
      item_page.visit_item(item_topic)

      expect(item_page).to have_comment_placeholder(
        I18n.t("js.kuu_ratings.score.comment_placeholder"),
      )

      item_page.pick_stars(2).submit_score

      expect(item_page).to have_comment_error(I18n.t("js.kuu_ratings.score.comment_required"))

      item_page.fill_in_comment("   ").submit_score

      expect(item_page).to have_comment_error(I18n.t("js.kuu_ratings.score.comment_required"))

      item_page.fill_in_comment("好").submit_score

      expect(item_page).to have_comment_error(
        I18n.t("js.kuu_ratings.score.comment_too_short", count: 2),
      )
      expect(item_page).to have_no_my_score
      expect(item_page).to have_summary(score: "8.0", count: 2)
      expect(DiscourseKuuRatings::RatingScore.exists?(user:)).to eq(false)

      item_page.fill_in_comment("好吃").submit_score

      expect(item_page).to have_my_score(4)
      expect(item_page).to have_summary(score: "6.7", count: 3)
      expect(item_page).to have_review_post(user, "好吃", score: 4)
    end

    context "when the site is in Chinese" do
      before do
        SiteSetting.default_locale = "zh_CN"
        user.update!(locale: "zh_CN")
      end

      it "asks the user to say something in Chinese" do
        item_page.visit_item(item_topic)

        expect(item_page).to have_comment_placeholder("说说你的体验")

        item_page.pick_stars(2).submit_score

        expect(item_page).to have_comment_error("说点什么吧～")

        item_page.fill_in_comment("好").submit_score

        expect(item_page).to have_comment_error("至少写 2 个字")
      end
    end

    it "lets the user delete their score and review after confirming" do
      add_review(user:, score: 8, comment: "Rich broth, firm noodles")

      item_page.visit_item(item_topic)

      expect(item_page).to have_my_score(8)
      expect(item_page).to have_review_post(user, "Rich broth, firm noodles", score: 8)

      item_page.delete_my_score

      expect(dialog).to be_open

      dialog.click_danger

      expect(item_page).to have_score_form
      expect(item_page).to have_no_my_score
      expect(item_page).to have_summary(score: "8.0", count: 2)

      page.refresh

      expect(item_page).to have_score_form
      expect(item_page).to have_no_review_post("Rich broth, firm noodles")
    end

    it "lets the user score the item on mobile", mobile: true do
      item_page.visit_item(item_topic)

      expect(item_page).to have_hidden_first_post
      expect(item_page).to have_start_scoring_button

      item_page.pick_stars(4).submit_score

      expect(item_page).to have_comment_error(I18n.t("js.kuu_ratings.score.comment_required"))
      expect(item_page).to have_no_my_score

      item_page.fill_in_comment("Rich broth, firm noodles").submit_score

      expect(item_page).to have_my_score(8)
      expect(item_page).to have_review_post(user, "Rich broth, firm noodles", score: 8)
    end

    it "takes the user to the score form instead of the composer" do
      item_page.visit_item(item_topic)

      expect(item_page).to have_start_scoring_button

      item_page.click_start_scoring

      expect(item_page).to have_scoring_focused
      expect(topic_page.composer).to be_closed
    end

    it "takes the user to the score form when they reply from the timeline" do
      # 只有首帖的话题不显示时间线
      add_review(user: Fabricate(:user), score: 8, comment: "Rich broth, firm noodles")

      item_page.visit_item(item_topic)
      item_page.click_timeline_reply

      expect(item_page).to have_scoring_focused
      expect(topic_page.composer).to be_closed
    end

    it "takes the user to the score form when they use the reply shortcut" do
      item_page.visit_item(item_topic)
      send_keys([:shift, "r"])

      expect(item_page).to have_scoring_focused
      expect(topic_page.composer).to be_closed
    end

    it "shows the user at most 3 top reviews" do
      reviews =
        [4, 3, 2, 1].map do |like_count|
          add_review(user: Fabricate(:user), score: 8, comment: "Review #{like_count}", like_count:)
        end

      item_page.visit_item(item_topic)

      expect(item_page).to have_hot_reviews(*reviews.first(3))
    end

    it "tells the user the item no longer accepts scores once the board is closed" do
      board_topic.update!(closed: true)

      item_page.visit_item(item_topic)

      expect(item_page).to have_notice("closed")
      expect(item_page).to have_no_score_form
    end
  end

  context "when not logged in" do
    it "asks the user to log in to score" do
      item_page.visit_item(item_topic)

      expect(item_page).to have_notice("login_to_score")
      expect(item_page).to have_no_score_form
    end
  end
end
