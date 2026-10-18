# frozen_string_literal: true

# 帖子流离开视口时会把帖子换成占位块（cloaking）。被插件藏起来的帖子（首帖、楼中楼的回复）
# 如果在换与不换之间高度不一样，就会反复切换，Chrome 和手机上整页跟着抖
RSpec.describe "Rating page scroll stability" do
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

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id

    3.times do |review_index|
      review =
        kuu_add_review(
          item_topic,
          user: Fabricate(:user),
          comment: "Review #{review_index}: rich broth and firm noodles",
        )
      review.update!(like_count: 3 - review_index)
      4.times { |index| kuu_reply_to(review, raw: "Reply #{index} to review #{review_index}") }
    end

    sign_in(user)
  end

  # 停止滚动后连续 60 帧，页面高度和滚动位置都不应该变
  def layout_samples
    page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      const samples = [];
      const tick = () => {
        samples.push([Math.round(window.scrollY), document.documentElement.scrollHeight]);
        if (samples.length < 60) {
          requestAnimationFrame(tick);
        } else {
          done(samples);
        }
      };
      requestAnimationFrame(tick);
    JS
  end

  def expect_stable_after_scrolling_to(selector)
    page.execute_script(<<~JS)
      const element = document.querySelector(#{selector.to_json});
      window.scrollTo(0, element.getBoundingClientRect().bottom + window.scrollY - 100);
    JS
    sleep 0.5

    samples = layout_samples
    expect(samples.map(&:first).uniq.size).to eq(1)
    expect(samples.map(&:last).uniq.size).to eq(1)
  end

  shared_examples "a stable rating page" do
    it "keeps the item page still below the top reviews" do
      visit(item_topic.relative_url)
      expect(page).to have_css(".kuu-hot-reviews")
      expect(page).to have_css(".kuu-review-thread")

      expect_stable_after_scrolling_to(".kuu-hot-reviews")
    end

    it "keeps the board page still below the item list" do
      visit(board_topic.relative_url)
      expect(page).to have_css(".kuu-board-item")

      expect_stable_after_scrolling_to(".kuu-board-items")
    end
  end

  it_behaves_like "a stable rating page"

  context "when on mobile", mobile: true do
    it_behaves_like "a stable rating page"
  end
end
