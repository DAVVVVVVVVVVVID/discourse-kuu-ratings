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
  # 插件的主要逻辑在这里注册（自定义字段、序列化器、事件等）
end
