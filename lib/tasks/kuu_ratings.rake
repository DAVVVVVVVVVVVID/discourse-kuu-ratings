# frozen_string_literal: true

# 先预演：DRY_RUN=1 rake kuu_ratings:backfill_star_reviews，只列出会补哪些，不写数据库；核对后再去掉 DRY_RUN 正式执行
desc "以前只打星、没写短评的打分，补一条「N星」短评（Issue #7，可以重复执行；DRY_RUN=1 只预演）"
task "kuu_ratings:backfill_star_reviews" => :environment do
  dry_run = ENV["DRY_RUN"].present? && ENV["DRY_RUN"] != "0"
  result = DiscourseKuuRatings::StarReviewBackfill.call(dry_run:)

  puts "【预演，没有写数据库】" if dry_run
  puts "#{dry_run ? "将补建" : "补建"} #{result.created.size} 条短评"
  result.created.each do |score, post|
    item = score.item_topic
    line =
      "  打分 #{score.id}：评分对象「#{item.title}」（topic #{item.id}），" \
        "打分人 #{score.user.username}，#{DiscourseKuuRatings::StarReviewBackfill.content(score)}，" \
        "原打分时间 #{score.created_at.iso8601}"
    line += " → post #{post.id}" if post
    puts line
  end

  puts "跳过 #{result.skipped.size} 条"
  result.skipped.each do |score, reason|
    puts "  打分 #{score.id}：user #{score.user_id}，topic #{score.item_topic_id}，原因 #{reason}"
  end
end
