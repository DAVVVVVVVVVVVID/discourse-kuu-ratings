# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::StarReviewBackfill do
  subject(:result) { described_class.call }

  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:reviewer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:one_star_voter, :user)
  fab!(:five_star_voter, :user)
  fab!(:watcher, :user)

  let(:start) { Time.zone.parse("2026-10-01 12:00") }
  # 时间线：首帖 → 短评 A → 只打 1 星 → 短评 B → 只打 5 星
  let!(:item_topic) do
    freeze_time(start) do
      create_post(user: owner, category: item_category, title: "Ichiran Ramen Kyoto").topic
    end
  end
  let!(:review_a) { review_at(start + 1.day, reviewer, "Rich broth, firm noodles") }
  let!(:one_star) { score_at(start + 2.days, one_star_voter, 2) }
  let!(:review_b) do
    review_at(start + 3.days, Fabricate(:user, refresh_auto_groups: true), "Too salty")
  end
  let!(:five_star) { score_at(start + 4.days, five_star_voter, 10) }

  before do
    SiteSetting.kuu_ratings_enabled = true
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def review_at(time, user, raw)
    freeze_time(time) do
      post = create_post(topic: item_topic, user:, raw:)
      DiscourseKuuRatings::RatingScore.create!(item_topic:, user:, score: 8, post:)
      post
    end
  end

  # 短评必填以前只打星、没有短评的打分
  def score_at(time, user, score)
    freeze_time(time) { DiscourseKuuRatings::RatingScore.create!(item_topic:, user:, score:) }
  end

  def created_post_for(score)
    result.created.to_h { |s, post| [s.id, post] }.fetch(score.id)
  end

  it "only backfills scores without a review" do
    expect { result }.to change { Post.count }.by(2)
    expect(result.created.map(&:first)).to contain_exactly(one_star, five_star)
    expect(result.skipped).to be_empty
    expect(DiscourseKuuRatings::RatingScore.find_by(post: review_a).user).to eq(reviewer)
    expect(review_a.reload.raw).to eq("Rich broth, firm noodles")
  end

  it "writes the number of stars as the review, by the voter, at the time of the score" do
    expect(created_post_for(one_star)).to have_attributes(
      raw: "1星",
      user: one_star_voter,
      topic: item_topic,
      created_at: eq_time(one_star.created_at),
    )
    expect(created_post_for(five_star)).to have_attributes(
      raw: "5星",
      user: five_star_voter,
      created_at: eq_time(five_star.created_at),
    )
  end

  it "links the reviews to the scores" do
    result

    expect(one_star.reload.post).to eq(created_post_for(one_star))
    expect(five_star.reload.post).to eq(created_post_for(five_star))
  end

  it "places each review after the last post written before the score" do
    result

    expect(Post.where(topic_id: item_topic.id).regular_order.pluck(:raw)).to eq(
      [item_topic.first_post.raw, "Rich broth, firm noodles", "1星", "Too salty", "5星"],
    )
  end

  it "notifies no one, not even users watching the item" do
    Jobs.run_immediately!
    TopicUser.change(
      watcher.id,
      item_topic.id,
      notification_level: TopicUser.notification_levels[:watching],
    )

    expect { result }.not_to change { Notification.count }
    expect(Notification.where(user: watcher)).to be_empty
  end

  it "does not bump the item" do
    bumped_at = item_topic.reload.bumped_at
    last_posted_at = item_topic.last_posted_at

    result

    item_topic.reload
    expect(item_topic.bumped_at).to eq_time(bumped_at)
    expect(item_topic.last_posted_at).to eq_time(last_posted_at)
  end

  it "does not change how the voter tracks the item" do
    TopicUser.change(
      one_star_voter.id,
      item_topic.id,
      notification_level: TopicUser.notification_levels[:regular],
    )

    result

    expect(TopicUser.get(item_topic, one_star_voter).notification_level).to eq(
      TopicUser.notification_levels[:regular],
    )
  end

  it "makes the number of scores match the number of reviews" do
    result

    scores = DiscourseKuuRatings::RatingScore.where(item_topic:)
    expect(scores.where.not(post_id: nil).count).to eq(scores.count)
    expect(item_topic.posts.where.not(post_number: 1).count).to eq(scores.count)
  end

  it "deletes the backfilled review when the voter deletes their score" do
    post = created_post_for(one_star)

    expect(
      DiscourseKuuRatings::RatingScore::Destroy.call(
        params: {
          item_topic_id: item_topic.id,
        },
        guardian: one_star_voter.guardian,
      ),
    ).to run_successfully
    expect(Post.find_by(id: post.id)).to be_nil
  end

  it "backfills nothing the second time" do
    described_class.call

    second = nil
    expect { second = described_class.call }.not_to change { Post.count }
    expect(second.created).to be_empty
    expect(second.skipped).to be_empty
  end

  context "when dry running" do
    subject(:result) { described_class.call(dry_run: true) }

    it "lists the scores it would backfill without writing anything" do
      expect { result }.to not_change { Post.with_deleted.count }.and not_change {
              DiscourseKuuRatings::RatingScore.where(post_id: nil).count
            }.and not_change { item_topic.reload.highest_post_number }

      expect(result.dry_run).to eq(true)
      expect(result.created).to contain_exactly([one_star, nil], [five_star, nil])
      expect(result.skipped).to be_empty
      expect(one_star.reload.post_id).to be_nil
    end

    it "still backfills when run for real afterwards" do
      result

      real = described_class.call
      expect(real.dry_run).to eq(false)
      expect(real.created.map(&:first)).to contain_exactly(one_star, five_star)
      expect(one_star.reload.post.raw).to eq("1星")
    end

    context "when the voter no longer exists" do
      before { one_star_voter.delete }

      it "lists the score as skipped" do
        expect(result.skipped).to contain_exactly([one_star, "user_deleted"])
      end
    end
  end

  context "when the voter no longer exists" do
    before { one_star_voter.delete }

    it "skips the score" do
      expect(result.skipped).to contain_exactly([one_star, "user_deleted"])
      expect(result.created.map(&:first)).to contain_exactly(five_star)
      expect(one_star.reload.post_id).to be_nil
    end
  end

  context "when the item has been deleted" do
    before { item_topic.trash! }

    it "skips its scores" do
      expect { result }.not_to change { Post.with_deleted.count }
      expect(result.skipped).to contain_exactly(
        [one_star, "item_deleted"],
        [five_star, "item_deleted"],
      )
      expect(result.created).to be_empty
    end
  end

  context "when the item no longer exists" do
    before { one_star.update_columns(item_topic_id: -1) }

    it "skips the score" do
      expect(result.skipped).to contain_exactly([one_star, "item_deleted"])
    end
  end
end
