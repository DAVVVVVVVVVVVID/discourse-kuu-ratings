# frozen_string_literal: true

# name: discourse-kuu-ratings
# about: 虎扑式评分：评分主题里有多个评分对象，用户打 0–10 分并写短评
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
  register_topic_custom_field_type(DiscourseKuuRatings::ItemFields::TAGLINE, :string)
  DiscourseKuuRatings::ItemFields::NAMES.each { |name| register_editable_topic_custom_field(name) }
  register_topic_custom_field_type(DiscourseKuuRatings::RatingScore::COUNT_FIELD, :integer)
  register_topic_custom_field_type(DiscourseKuuRatings::RatingScore::AVG_FIELD, :string)

  # 进审核队列时 core 只保存正文、标签等，不加这一项自定义字段会丢
  if NewPostManager.plugin_payload_attributes.exclude?(:topic_opts)
    NewPostManager.add_plugin_payload_attribute(:topic_opts)
  end

  # NewPostManager 的 handler 是全局的，插件关闭时由 ReplyRules 自己跳过
  NewPostManager.add_handler(100) { |manager| DiscourseKuuRatings::ReplyRules.check(manager) }

  on(:after_validate_topic) do |topic, creator|
    DiscourseKuuRatings::ItemFields.validate(topic, creator)
  end

  on(:approved_post) do |reviewable, post|
    DiscourseKuuRatings::ItemFields.restore_after_approval(reviewable, post)
  end

  on(:post_destroyed) do |post|
    DiscourseKuuRatings::RatingScore::DestroyForDeletedPost.call(params: { post_id: post.id })
  end

  on(:user_destroyed) do |user|
    DiscourseKuuRatings::RatingScore::DestroyForDeletedUser.call(params: { user_id: user.id })
  end
end
