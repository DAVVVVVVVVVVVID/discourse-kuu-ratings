# frozen_string_literal: true

module DiscourseKuuRatings
  # 用户被删除时，带短评的打分已经随短评一起删掉了（DestroyForDeletedPost），
  # 这里删掉剩下的只打分、没写短评的记录，免得被删用户的分数还算在平均分里
  class RatingScore::DestroyForDeletedUser
    include Service::Base

    params do
      attribute :user_id, :integer

      validates :user_id, presence: true
    end

    model :rating_scores
    model :item_topics

    transaction do
      step :destroy_rating_scores
      each(:item_topics) { step :refresh_item_stats }
    end

    private

    def fetch_rating_scores(params:)
      RatingScore.where(user_id: params.user_id)
    end

    # 删除前就要取出来；按 id 排序，多个删除同时进行时按同样的顺序锁 topic 行，避免死锁
    def fetch_item_topics(rating_scores:)
      Topic.with_deleted.where(id: rating_scores.select(:item_topic_id)).order(:id).to_a
    end

    def destroy_rating_scores(rating_scores:)
      rating_scores.delete_all
    end

    def refresh_item_stats(item_topic:)
      RatingScore.refresh_item_stats(item_topic)
    end
  end
end
