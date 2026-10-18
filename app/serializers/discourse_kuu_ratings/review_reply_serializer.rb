# frozen_string_literal: true

module DiscourseKuuRatings
  # 楼中楼里的一条回复；赞过没有、回复人的打分等由 options[:thread_batch]（ReviewThreadBatch）一次查好
  class ReviewReplySerializer < ApplicationSerializer
    attributes :id,
               :post_number,
               :cooked,
               :created_at,
               :like_count,
               :liked,
               :can_like,
               :can_edit,
               :can_delete,
               :reply_to_username,
               :kuu_score

    has_one :user, serializer: BasicUserSerializer, embed: :objects

    def liked
      thread_batch.liked?(object.id)
    end

    def can_like
      scope.post_can_act?(object, :like)
    end

    def can_edit
      scope.can_edit?(object)
    end

    def can_delete
      scope.can_delete?(object)
    end

    def reply_to_username
      thread_batch.reply_to_username(object)
    end

    def include_reply_to_username?
      reply_to_username.present?
    end

    def kuu_score
      thread_batch.score_for(object.user_id)
    end

    private

    def thread_batch
      @options[:thread_batch]
    end
  end
end
