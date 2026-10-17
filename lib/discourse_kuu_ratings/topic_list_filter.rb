# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象数量多，不让它们刷屏「最新」等话题列表和帖子底部的推荐；
  # 只有直接打开评分对象分类时才列出来，评分主题页有自己的对象列表
  module TopicListFilter
    def self.call(results, topic_query)
      return results if !SiteSetting.kuu_ratings_enabled

      item_category_id = ItemFields.item_category_id
      return results if item_category_id <= 0
      return results if listing_category_id(topic_query.options[:category]) == item_category_id

      results.where("topics.category_id IS DISTINCT FROM ?", item_category_id)
    end

    # 和 TopicQuery#get_category_id 一样解析：core 按哪个分类筛选，这里就认哪个
    def self.listing_category_id(category)
      return if category.blank?

      category_id = category.to_i
      return category_id if category_id != 0

      Category.where(slug: category, parent_category_id: nil).pick(:id)
    end
  end
end
