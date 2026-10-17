# frozen_string_literal: true

# name: discourse-kuu-ratings
# about: 虎扑式评分：评分主题里有多个评分对象，用户打 1–5 星（10 分制）并写短评
# version: 0.0.1
# authors: DAVVVVVVVVVVVID
# url: https://github.com/DAVVVVVVVVVVVID/discourse-kuu-ratings
# required_version: 2026.1.0

enabled_site_setting :kuu_ratings_enabled


module ::DiscourseKuuRatings
  PLUGIN_NAME = "discourse-kuu-ratings"
end

require_relative "lib/discourse_kuu_ratings/engine"

after_initialize do
  register_topic_custom_field_type(DiscourseKuuRatings::ItemFields::BOARD_TOPIC_ID, :integer)
  register_topic_custom_field_type(DiscourseKuuRatings::RatingScore::COUNT_FIELD, :integer)
  register_topic_custom_field_type(DiscourseKuuRatings::RatingScore::AVG_FIELD, :string)

  register_reviewable_type ReviewableKuuRatingSubmission

  # 评分对象帖子里每条发言旁边显示作者的分数。帖子页一次查出全部，避免每条回帖查一次
  add_to_class(:topic_view, :kuu_scores_by_user_id) do
    @kuu_scores_by_user_id ||=
      DiscourseKuuRatings::RatingScore.where(item_topic_id: topic.id).pluck(:user_id, :score).to_h
  end

  add_to_serializer(
    :post,
    :kuu_score,
    include_condition: -> do
      DiscourseKuuRatings::ItemFields.item_category?(object.topic&.category_id)
    end,
  ) do
    if @topic_view
      @topic_view.kuu_scores_by_user_id[object.user_id]
    else
      DiscourseKuuRatings::RatingScore.where(
        item_topic_id: object.topic_id,
        user_id: object.user_id,
      ).pick(:score)
    end
  end

  # NewPostManager 的 handler 是全局的，插件关闭时由 ReplyRules 自己跳过
  NewPostManager.add_handler(100) { |manager| DiscourseKuuRatings::ReplyRules.check(manager) }

  on(:post_destroyed) do |post|
    DiscourseKuuRatings::RatingScore::DestroyForDeletedPost.call(params: { post_id: post.id })
  end

  on(:user_destroyed) do |user|
    DiscourseKuuRatings::RatingScore::DestroyForDeletedUser.call(params: { user_id: user.id })
  end
end
