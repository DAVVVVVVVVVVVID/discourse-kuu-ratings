# frozen_string_literal: true

module DiscourseKuuRatings
  # 楼中楼：评分对象帖子里对短评（或对短评下某条回复）的回复，都收进最顶上那条短评的楼里。
  # 回复仍是普通回帖，所属短评存在帖子自定义字段里，查询时不用沿回复链往上找
  module ReviewThreads
    ROOT_FIELD = "kuu_root_review_post_id"
    REPLY_MAX_LENGTH = RatingScore::COMMENT_MAX_LENGTH
    PREVIEW_SIZE = 3
    PAGE_SIZE = 10

    # 被回复的那条所在的楼；回复首帖（评分对象本身）或者找不到被回复的帖子时返回 nil
    def self.root_review_id(topic_id, reply_to_post_number)
      return if reply_to_post_number.to_i <= 1

      target = Post.with_deleted.find_by(topic_id:, post_number: reply_to_post_number)
      return if target.nil?

      target.custom_fields[ROOT_FIELD].presence&.to_i || target.id
    end

    # 新建回帖时（包括审核通过后才建出来的）记下所属短评
    def self.assign_root(post)
      return if !SiteSetting.kuu_ratings_enabled
      return if !ItemFields.item_category?(post.topic&.category_id)

      root_id = root_review_id(post.topic_id, post.reply_to_post_number)
      return if root_id.nil?

      post.custom_fields[ROOT_FIELD] = root_id
      post.save_custom_fields
    end

    # 短评：评分对象帖子里不是回复别人的普通回帖（打分接口发出的）。
    # 调用方要先确认它不属于任何楼（没有 ROOT_FIELD），这里不再查自定义字段
    def self.review?(post)
      post.post_number > 1 && post.post_type == Post.types[:regular] &&
        post.reply_to_post_number.to_i <= 1
    end

    def self.root_id_of(post)
      post.custom_fields[ROOT_FIELD].presence&.to_i
    end

    # 某几条短评楼里当前用户看得到的回复（不含已删除的），按发帖顺序
    def self.replies_scope(root_ids, guardian)
      Post
        .secured(guardian)
        .joins(<<~SQL)
          INNER JOIN post_custom_fields kuu_root
            ON kuu_root.post_id = posts.id AND kuu_root.name = '#{ROOT_FIELD}'
        SQL
        .where("kuu_root.value IN (?)", Array(root_ids).map(&:to_s))
    end

    def self.reply_counts(root_ids, guardian)
      return {} if root_ids.blank?

      replies_scope(root_ids, guardian).group("kuu_root.value").count.transform_keys(&:to_i)
    end

    # 每条短评的前 PREVIEW_SIZE 条回复：{ root_id => [post, ...] }
    def self.preview_replies(root_ids, guardian)
      return {} if root_ids.blank?

      ranked =
        replies_scope(root_ids, guardian).select(
          "posts.*",
          "kuu_root.value::integer AS kuu_root_id",
          "ROW_NUMBER() OVER (PARTITION BY kuu_root.value ORDER BY posts.post_number) AS kuu_rank",
        )

      # Post 有 ignored_columns，默认会逐列列出，要写 posts.* 才能带上子查询里的 kuu_root_id
      Post
        .from(ranked, :posts)
        .select("posts.*")
        .where("kuu_rank <= ?", PREVIEW_SIZE)
        .order(:post_number)
        .includes(:user)
        .group_by(&:kuu_root_id)
    end
  end
end
