# frozen_string_literal: true

module DiscourseKuuRatings
  # 热评：一条带短评的打分
  class ReviewSerializer < ApplicationSerializer
    attributes :post_id, :post_number, :score, :like_count, :cooked, :created_at

    has_one :user, serializer: BasicUserSerializer, embed: :objects

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
