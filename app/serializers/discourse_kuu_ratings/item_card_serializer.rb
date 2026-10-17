# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分主题页的一张卡片；热评由调用方一次查好，通过 options[:hot_reviews] 传入
  class ItemCardSerializer < ItemSerializer
    attributes :created_at, :closed

    has_one :hot_review, serializer: ReviewSerializer, embed: :objects

    def hot_review
      @options[:hot_reviews][object.id]
    end
  end
end
