# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象帖子里，直接回复对象的只能是短评（由打分接口直接用 PostCreator 发出）。
  # 普通发帖流程（网页、API、邮件）都经过 NewPostManager，在这里只放行对短评和回复的回复
  module ReplyRules
    def self.check(manager)
      return if !SiteSetting.kuu_ratings_enabled

      args = manager.args
      return if args[:topic_id].blank?
      return if !Topic.exists?(id: args[:topic_id], category_id: ItemFields.item_category_id)
      return if replying_to_review_thread?(args)

      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, I18n.t("kuu_ratings.errors.reply_to_item_not_allowed"))
      result
    end

    def self.replying_to_review_thread?(args)
      post_number = args[:reply_to_post_number].to_i
      post_number > 1 && Post.exists?(topic_id: args[:topic_id], post_number:)
    end
  end
end
