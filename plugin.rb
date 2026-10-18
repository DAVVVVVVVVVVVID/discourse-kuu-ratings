# frozen_string_literal: true

# name: discourse-kuu-ratings
# about: 虎扑式评分：评分主题里有多个评分对象，用户打 1–5 星（10 分制）并写短评
# version: 0.0.1
# authors: DAVVVVVVVVVVVID
# url: https://github.com/DAVVVVVVVVVVVID/discourse-kuu-ratings
# required_version: 2026.1.0

enabled_site_setting :kuu_ratings_enabled

register_asset "stylesheets/common/kuu-ratings.scss"

module ::DiscourseKuuRatings
  PLUGIN_NAME = "discourse-kuu-ratings"
end

require_relative "lib/discourse_kuu_ratings/engine"

after_initialize do
  register_topic_custom_field_type(DiscourseKuuRatings::ItemFields::BOARD_TOPIC_ID, :integer)
  register_topic_custom_field_type(DiscourseKuuRatings::RatingScore::COUNT_FIELD, :integer)
  register_topic_custom_field_type(DiscourseKuuRatings::RatingScore::AVG_FIELD, :string)

  register_post_custom_field_type(DiscourseKuuRatings::ReviewThreads::ROOT_FIELD, :integer)
  topic_view_post_custom_fields_allowlister { [DiscourseKuuRatings::ReviewThreads::ROOT_FIELD] }

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

  # 楼中楼：帖子页一次查好所有短评的前几条回复和回复数
  add_to_class(:topic_view, :kuu_review_thread_batch) do
    @kuu_review_thread_batch ||=
      begin
        root_ids =
          posts.filter_map do |post|
            root_id =
              post_custom_fields.dig(post.id, DiscourseKuuRatings::ReviewThreads::ROOT_FIELD)
            root_id.present? ? root_id.to_i : (post.id if post.post_number > 1)
          end
        DiscourseKuuRatings::ReviewThreadBatch.new(item_topic_id: topic.id, root_ids:, guardian:)
      end
  end

  add_to_serializer(
    :post,
    :kuu_root_review_post_id,
    include_condition: -> do
      DiscourseKuuRatings::ItemFields.item_category?(object.topic&.category_id) &&
        kuu_root_review_post_id.present?
    end,
  ) do
    root_id =
      if @topic_view
        @topic_view.post_custom_fields.dig(
          object.id,
          DiscourseKuuRatings::ReviewThreads::ROOT_FIELD,
        )
      else
        object.custom_fields[DiscourseKuuRatings::ReviewThreads::ROOT_FIELD]
      end
    root_id.presence&.to_i
  end

  # 短评带上自己的楼；短评被删除时由楼里第一条回复代为带上（短评本身不会发给普通用户）
  add_to_serializer(
    :post,
    :kuu_thread,
    include_condition: -> do
      DiscourseKuuRatings::ItemFields.item_category?(object.topic&.category_id) &&
        kuu_thread.present?
    end,
  ) do
    @kuu_thread ||=
      begin
        root_id = kuu_root_review_post_id
        batch =
          @topic_view&.kuu_review_thread_batch ||
            DiscourseKuuRatings::ReviewThreadBatch.new(
              item_topic_id: object.topic_id,
              root_ids: [root_id || object.id],
              guardian: scope,
            )

        if root_id.nil?
          batch.thread_json(object.id) if DiscourseKuuRatings::ReviewThreads.review?(object)
        elsif batch.root_deleted?(root_id) && batch.replies_for(root_id).first&.id == object.id
          batch.thread_json(root_id).merge(anchor: true)
        end
      end
  end

  # NewPostManager 的 handler 是全局的，插件关闭时由 ReplyRules 自己跳过
  NewPostManager.add_handler(100) { |manager| DiscourseKuuRatings::ReplyRules.check(manager) }
  NewPostManager.add_handler(-100) do |manager|
    DiscourseKuuRatings::ReplyRules.create_thread_reply(manager)
  end

  # 审核通过后建出来的回帖不触发 :post_created，所以两个事件都要处理
  on(:post_created) { |post| DiscourseKuuRatings::ReviewThreads.assign_root(post) }
  on(:approved_post) { |_reviewable, post| DiscourseKuuRatings::ReviewThreads.assign_root(post) }

  TopicQuery.add_custom_filter(:kuu_ratings_hide_items) do |results, topic_query|
    DiscourseKuuRatings::TopicListFilter.call(results, topic_query)
  end

  on(:post_destroyed) do |post|
    DiscourseKuuRatings::RatingScore::DestroyForDeletedPost.call(params: { post_id: post.id })
  end

  on(:user_destroyed) do |user|
    DiscourseKuuRatings::RatingScore::DestroyForDeletedUser.call(params: { user_id: user.id })
  end
end
