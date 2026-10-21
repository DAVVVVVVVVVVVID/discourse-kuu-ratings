# frozen_string_literal: true

module DiscourseKuuRatings
  # 2026-10-21 起短评必填（Issue #7）。以前只打星、没写短评的打分，补一条内容为「N星」的短评，
  # 让评分对象页上的打分人数和短评条数对得上。由 rake kuu_ratings:backfill_star_reviews 执行，
  # 只处理 post_id 为空的打分，跑多少次都不会重复补。
  # dry_run: true 时只列出会补哪些（created 里的帖子是 nil），不写数据库，执行前先核对
  module StarReviewBackfill
    Result = Struct.new(:created, :skipped, :dry_run)

    def self.call(dry_run: false)
      result = Result.new([], [], dry_run)

      RatingScore
        .where(post_id: nil)
        .includes(:user, :item_topic)
        .order(:id)
        .each do |score|
          if (reason = skip_reason(score))
            result.skipped << [score, reason]
          else
            result.created << [score, dry_run ? nil : create_review(score)]
          end
        end

      result
    end

    def self.skip_reason(score)
      return "user_deleted" if score.user.nil?
      "item_deleted" if score.item_topic.nil? || score.item_topic.trashed?
    end

    def self.content(score)
      "#{score.score / RatingScore::POINTS_PER_STAR}星"
    end

    # 和打分接口建短评走同一条路（PostCreator，长度由插件自己管），另外：
    # 不发通知（skip_jobs、skip_events）、不顶帖（no_bump）、不改话题的最后回复时间等统计（silent）、
    # 不改作者对话题的跟踪状态（auto_track），时间用原来的打分时间
    def self.create_review(score)
      RatingScore.transaction do
        post =
          PostCreator.new(
            score.user,
            topic_id: score.item_topic_id,
            raw: content(score),
            created_at: score.created_at,
            skip_validations: true,
            skip_rate_limits: true,
            skip_jobs: true,
            skip_events: true,
            no_bump: true,
            silent: true,
            auto_track: false,
          ).create!

        place_by_time(post)
        score.update_columns(post_id: post.id)
        post
      end
    end

    # 帖子按 sort_order、再按楼号排。补建的短评和「打分时间之前最后一条帖子」用同一个 sort_order，
    # 就排在它后面，其他帖子都不用动（楼号是新编的，所以楼号不再按顺序）
    def self.place_by_time(post)
      previous =
        Post
          .with_deleted
          .where(topic_id: post.topic_id)
          .where.not(id: post.id)
          .where("created_at <= ?", post.created_at)
          .order(sort_order: :desc, post_number: :desc)
          .pick(:sort_order)

      post.update_columns(sort_order: previous) if previous
    end
  end
end
