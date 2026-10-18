# frozen_string_literal: true

module DiscourseKuuRatings
  # 某条短评楼里的回复，按发帖顺序分页（「共 N 条回复，点击查看」）。短评已删除时楼里的回复照常列出
  class Review::ListReplies
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :offset, :integer, default: 0

      validates :post_id, presence: true
      validates :offset, numericality: { greater_than_or_equal_to: 0 }
    end

    model :review
    policy :can_see_review
    model :replies, optional: true
    model :thread_batch

    private

    def fetch_review(params:)
      review = Post.with_deleted.includes(:topic).find_by(id: params.post_id)
      return if review.nil? || !ItemFields.item_category?(review.topic&.category_id)
      return if !ReviewThreads.review?(review) || ReviewThreads.root_id_of(review)

      review
    end

    def can_see_review(guardian:, review:)
      guardian.can_see_topic?(review.topic)
    end

    # 多取一条，用来判断后面还有没有
    def fetch_replies(guardian:, review:, params:)
      ReviewThreads
        .replies_scope([review.id], guardian)
        .order(:post_number)
        .offset(params.offset)
        .limit(ReviewThreads::PAGE_SIZE + 1)
        .to_a
    end

    def fetch_thread_batch(guardian:, review:, replies:)
      ReviewThreadBatch.new(
        item_topic_id: review.topic_id,
        root_ids: [review.id],
        guardian:,
        replies: replies.first(ReviewThreads::PAGE_SIZE),
      )
    end
  end
end
