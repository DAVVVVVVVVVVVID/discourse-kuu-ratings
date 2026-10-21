# frozen_string_literal: true

RSpec.describe "kuu_ratings rake tasks" do
  describe "kuu_ratings:backfill_star_reviews" do
    fab!(:item_category, :category)
    fab!(:item_topic) do
      Fabricate(:topic_with_op, category: item_category, title: "Ichiran Ramen Kyoto")
    end
    fab!(:deleted_item) { Fabricate(:topic_with_op, category: item_category) }
    fab!(:voter) { Fabricate(:user, username: "ramen_fan") }
    fab!(:score) do
      Fabricate(
        :kuu_rating_score,
        item_topic:,
        user: voter,
        score: 6,
        created_at: Time.zone.parse("2026-10-01 12:34:56"),
      )
    end
    fab!(:skipped_score) { Fabricate(:kuu_rating_score, item_topic: deleted_item, score: 4) }

    let(:score_line) do
      "  打分 #{score.id}：评分对象「Ichiran Ramen Kyoto」（topic #{item_topic.id}），" \
        "打分人 ramen_fan，3星，原打分时间 #{score.created_at.iso8601}"
    end
    let(:skipped_line) do
      "  打分 #{skipped_score.id}：user #{skipped_score.user_id}，" \
        "topic #{deleted_item.id}，原因 item_deleted"
    end

    before do
      SiteSetting.kuu_ratings_item_category = item_category.id
      deleted_item.trash!
    end

    def run_task(dry_run: nil)
      previous = ENV["DRY_RUN"]
      ENV["DRY_RUN"] = dry_run
      capture_stdout { invoke_rake_task("kuu_ratings:backfill_star_reviews") }
    ensure
      ENV["DRY_RUN"] = previous
    end

    it "backfills the reviews and lists what it created and skipped" do
      output = run_task

      post = score.reload.post
      expect(post).to have_attributes(raw: "3星", user: voter)
      expect(output.lines.map(&:chomp)).to eq(
        ["补建 1 条短评", "#{score_line} → post #{post.id}", "跳过 1 条", skipped_line],
      )
    end

    it "only lists what it would do when dry running" do
      output = nil
      expect { output = run_task(dry_run: "1") }.not_to change { Post.with_deleted.count }

      expect(score.reload.post_id).to be_nil
      expect(output.lines.map(&:chomp)).to eq(
        ["【预演，没有写数据库】", "将补建 1 条短评", score_line, "跳过 1 条", skipped_line],
      )
    end

    it "runs for real when DRY_RUN is 0" do
      output = run_task(dry_run: "0")

      expect(output).not_to include("预演")
      expect(score.reload.post.raw).to eq("3星")
    end

    it "still backfills after a dry run" do
      run_task(dry_run: "1")
      output = run_task

      expect(output).to start_with("补建 1 条短评")
      expect(score.reload.post.raw).to eq("3星")
    end
  end
end
