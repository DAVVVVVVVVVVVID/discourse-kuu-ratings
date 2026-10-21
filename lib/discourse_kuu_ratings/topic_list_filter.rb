# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象帖不出现在任何帖子列表里（包括「评分对象」分类页本身、用户活动、帖子底部的推荐），
  # 只能从评分主题点进去；链接照样能打开，搜索也照样搜得到（Issue #4，2026-10-21 David 定）
  module TopicListFilter
    def self.call(results, _topic_query)
      return results if !SiteSetting.kuu_ratings_enabled

      item_category_id = ItemFields.item_category_id
      return results if item_category_id <= 0

      results.where("topics.category_id IS DISTINCT FROM ?", item_category_id)
    end
  end
end
