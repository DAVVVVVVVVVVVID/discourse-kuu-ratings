# frozen_string_literal: true

module DiscourseKuuRatings
  # 删除自己的打分，短评一起删，删除后可以重新打分
  class RatingScore::Destroy
    include Service::Base

    params do
      attribute :item_topic_id, :integer

      validates :item_topic_id, presence: true
    end

    model :rating_score

    transaction do
      step :destroy_rating_score
      only_if(:has_comment_post) { step :destroy_comment_post }
      step :refresh_item_stats
    end

    private

    def fetch_rating_score(guardian:, params:)
      RatingScore.includes(:item_topic, :post).find_by(
        item_topic_id: params.item_topic_id,
        user: guardian.user,
      )
    end

    def destroy_rating_score(rating_score:)
      rating_score.destroy!
    end

    def has_comment_post(rating_score:)
      rating_score.post.present?
    end

    # 不传 delete_removed_posts_after: 0 的话，作者删自己的帖子只会被标记，24 小时后才真删
    def destroy_comment_post(guardian:, rating_score:)
      PostDestroyer.new(guardian.user, rating_score.post, delete_removed_posts_after: 0).destroy
    end

    def refresh_item_stats(rating_score:)
      RatingScore.refresh_item_stats(rating_score.item_topic)
    end
  end
end
