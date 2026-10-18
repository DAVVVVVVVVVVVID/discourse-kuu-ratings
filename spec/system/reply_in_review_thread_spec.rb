# frozen_string_literal: true

RSpec.describe "Reply in review thread" do
  fab!(:user) { Fabricate(:user, username: "ramenfan", refresh_auto_groups: true) }
  fab!(:reviewer) { Fabricate(:user, username: "reviewer", refresh_auto_groups: true) }
  fab!(:replier) { Fabricate(:user, username: "replier", refresh_auto_groups: true) }
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

  let(:item_page) { PageObjects::Pages::KuuRatingsItem.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    # 楼里的「+1」不受回帖最短长度限制
    SiteSetting.min_post_length = 8
  end

  def add_review(user: reviewer, comment: "Rich broth, firm noodles", like_count: 0)
    review = kuu_add_review(item_topic, user:, comment:)
    review.update!(like_count:)
    review
  end

  def add_replies(review, count)
    Array.new(count) { |index| kuu_reply_to(review, user: replier, raw: "Reply number #{index}") }
  end

  context "when logged in" do
    before { sign_in(user) }

    shared_examples "a thread under each review" do
      it "lets the user see replies inside the thread of the review" do
        review = add_review
        reply = kuu_reply_to(review, user: replier, raw: "Agreed, the broth is great")
        reply_to_reply = kuu_reply_to(reply, raw: "Same here, go early")

        item_page.visit_item(item_topic)

        expect(item_page).to have_post_in_stream(review)
        expect(item_page).to have_no_post_in_stream(reply)
        expect(item_page).to have_no_post_in_stream(reply_to_reply)
        expect(item_page.review_thread(review)).to have_replies(reply, reply_to_reply)
        expect(item_page.review_thread(review)).to have_reply_to("Same here, go early", replier)
        expect(topic_page).to have_no_post_action_button(review, :replies)
      end

      it "lets the user reply to a review and to a reply without the composer" do
        review = add_review
        reply = kuu_reply_to(review, user: replier, raw: "Agreed, the broth is great")
        thread = item_page.review_thread(review)

        item_page.visit_item(item_topic)
        topic_page.click_post_action_button(review, :reply)

        expect(thread).to have_reply_input
        expect(topic_page.composer).to be_closed

        thread.send_reply("+1")

        expect(thread).to have_reply(user, "+1")
        expect(thread).to have_no_reply_input

        thread.click_reply_on(reply).send_reply("Totally agree")

        expect(thread).to have_reply_to("Totally agree", replier)
        expect(thread).to have_reply_count(3)

        page.refresh

        expect(thread).to have_reply(user, "+1")
        expect(thread).to have_reply_to("Totally agree", replier)
      end

      it "shows the user the replies of a deleted review without letting them reply" do
        review = add_review
        reply = kuu_reply_to(review, user: replier, raw: "Agreed, the broth is great")
        lonely_review = add_review(user: Fabricate(:user), comment: "Too salty for me")
        review.trash!
        lonely_review.trash!

        item_page.visit_item(item_topic)

        expect(item_page.review_thread(review)).to have_deleted_notice
        expect(item_page.review_thread(review)).to have_replies(reply)
        expect(item_page.review_thread(review)).to have_no_reply_buttons
        expect(item_page).to have_no_post_in_stream(reply)
        expect(item_page).to have_no_review_post("Too salty for me")
        expect(item_page.review_thread(lonely_review)).to be_not_shown
      end
    end

    it_behaves_like "a thread under each review"

    context "when on mobile", mobile: true do
      it_behaves_like "a thread under each review"
    end

    it "lets the user load all replies 10 at a time" do
      review = add_review
      replies = add_replies(review, 15)
      thread = item_page.review_thread(review)

      item_page.visit_item(item_topic)

      expect(thread).to have_replies(*replies.first(3))
      expect(thread).to have_view_all_button(15)

      thread.click_more

      expect(thread).to have_replies(*replies.first(13))
      expect(thread).to have_view_more_button

      thread.click_more

      expect(thread).to have_replies(*replies)
      expect(thread).to have_no_more_button
    end

    it "lets the user like and unlike a reply without changing the hot reviews" do
      top_review = add_review(like_count: 3)
      other_review = add_review(user: Fabricate(:user), comment: "Too salty", like_count: 1)
      reply = kuu_reply_to(other_review, user: replier, raw: "Agreed, way too salty")
      Array.new(4) { PostActionCreator.like(Fabricate(:user, refresh_auto_groups: true), reply) }
      thread = item_page.review_thread(other_review)

      item_page.visit_item(item_topic)
      thread.toggle_like(reply)

      expect(thread).to have_liked_reply(reply, count: 5)

      page.refresh

      expect(thread).to have_liked_reply(reply, count: 5)
      expect(item_page).to have_hot_reviews(top_review, other_review)

      thread.toggle_like(reply)

      expect(thread).to have_unliked_reply(reply, count: 4)

      page.refresh

      expect(thread).to have_unliked_reply(reply, count: 4)
    end

    it "takes the user to a linked reply inside its thread" do
      review = add_review
      replies = add_replies(review, 6)

      item_page.visit_post(replies[4])

      expect(item_page.review_thread(review)).to have_highlighted_reply(replies[4])
      expect(item_page.review_thread(review)).to have_reply_count(6)
    end

    it "shows the user how many replies each hot review has" do
      review = add_review(like_count: 1)
      add_replies(review, 2)

      item_page.visit_item(item_topic)

      expect(item_page).to have_hot_review_reply_count(review, count: 2)
    end

    it "tells the user their reply is waiting for approval" do
      SiteSetting.approve_post_count = 5
      review = add_review
      thread = item_page.review_thread(review)

      item_page.visit_item(item_topic)
      topic_page.click_post_action_button(review, :reply)
      thread.send_reply("+1")

      expect(toasts).to have_success(I18n.t("js.kuu_ratings.thread.enqueued"))
      expect(thread).to have_reply_count(0)
    end
  end
end
