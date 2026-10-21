# frozen_string_literal: true

module DiscourseKuuRatings
  class RatingScore < ActiveRecord::Base
    self.table_name = "kuu_rating_scores"

    # 10 分制，界面是五颗星，每颗 2 分，只能选整颗星
    MAX_STARS = 5
    POINTS_PER_STAR = 2
    VALID_SCORES = (1..MAX_STARS).map { |stars| stars * POINTS_PER_STAR }.freeze
    COMMENT_MAX_LENGTH = 500
    # 短评必填：「好吃」这种两个字也行（Issue #7）
    COMMENT_LENGTH = (2..COMMENT_MAX_LENGTH)
    AVG_FIELD = "kuu_score_avg"
    COUNT_FIELD = "kuu_score_count"

    belongs_to :item_topic, -> { with_deleted }, class_name: "Topic"
    belongs_to :user
    belongs_to :post, optional: true

    validates :score, inclusion: { in: VALID_SCORES }
    validates :user_id, uniqueness: { scope: :item_topic_id }

    def self.score_for_stars(stars)
      stars * POINTS_PER_STAR
    end

    # 每个对象点赞最多的前 per_item 条短评（至少 1 个赞，赞数相同时先发的在前）
    def self.hot_reviews(item_topic_ids, per_item:)
      ranked =
        joins(:post)
          .where(item_topic_id: item_topic_ids)
          .where(posts: { deleted_at: nil, hidden: false, post_type: Post.types[:regular] })
          .where("posts.like_count > 0")
          .select(
            "kuu_rating_scores.*",
            "ROW_NUMBER() OVER (PARTITION BY kuu_rating_scores.item_topic_id ORDER BY posts.like_count DESC, posts.created_at ASC) AS hot_rank",
          )

      from(ranked, :kuu_rating_scores)
        .where("hot_rank <= ?", per_item)
        .order(:item_topic_id, :hot_rank)
        .includes(post: :user)
    end

    # 必须在事务里调用。先锁住 topic 行，让并发的打分、删除排队，
    # 这样最后一次重算一定能看到所有已提交的打分
    def self.refresh_item_stats(item_topic)
      Topic.where(id: item_topic.id).lock.pluck(:id)
      count, avg = where(item_topic:).pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(score)"))

      item_topic.custom_fields[COUNT_FIELD] = count
      item_topic.custom_fields[AVG_FIELD] = avg&.round(2)&.to_s
      item_topic.save_custom_fields(true)
    end
  end
end

# == Schema Information
#
# Table name: kuu_rating_scores
#
#  id            :bigint           not null, primary key
#  score         :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  item_topic_id :integer          not null
#  post_id       :integer
#  user_id       :integer          not null
#
# Indexes
#
#  index_kuu_rating_scores_on_item_topic_id_and_user_id  (item_topic_id,user_id) UNIQUE
#  index_kuu_rating_scores_on_post_id                    (post_id) UNIQUE WHERE (post_id IS NOT NULL)
#  index_kuu_rating_scores_on_user_id_and_created_at     (user_id,created_at)
#
