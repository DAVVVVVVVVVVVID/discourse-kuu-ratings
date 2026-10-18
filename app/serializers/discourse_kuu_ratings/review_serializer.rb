# frozen_string_literal: true

module DiscourseKuuRatings
  # 热评：一条带短评的打分
  class ReviewSerializer < ApplicationSerializer
    attributes :post_id, :post_number, :score, :like_count, :cooked, :created_at, :reply_count

    has_one :user, serializer: BasicUserSerializer, embed: :objects

    # 只有评分对象页的热评区带回复数（由调用方一次查好传进来）；评分主题页的卡片不带
    def reply_count
      @options[:reply_counts].fetch(object.post_id, 0)
    end

    def include_reply_count?
      @options.key?(:reply_counts)
    end

    def post_number
      object.post.post_number
    end

    def like_count
      object.post.like_count
    end

    def cooked
      object.post.cooked
    end

    def user
      object.post.user
    end
  end
end
