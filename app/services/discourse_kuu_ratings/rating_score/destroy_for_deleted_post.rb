# frozen_string_literal: true

module DiscourseKuuRatings
  # 短评不管从哪里被删掉（作者自己、管理员、处理举报、删除用户……），对应的打分都一起删
  class RatingScore::DestroyForDeletedPost
    include Service::Base

    params do
      attribute :post_id, :integer

      validates :post_id, presence: true
    end

    model :rating_score

    transaction do
      step :destroy_rating_score
      step :refresh_item_stats
    end

    private

    def fetch_rating_score(params:)
      RatingScore.includes(:item_topic).find_by(post_id: params.post_id)
    end

    def destroy_rating_score(rating_score:)
      rating_score.destroy!
    end

    def refresh_item_stats(rating_score:)
      RatingScore.refresh_item_stats(rating_score.item_topic)
    end
  end
end
