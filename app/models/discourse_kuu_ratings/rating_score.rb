# frozen_string_literal: true

module DiscourseKuuRatings
  class RatingScore < ActiveRecord::Base
    self.table_name = "kuu_rating_scores"

    MIN_SCORE = 0
    MAX_SCORE = 10

    belongs_to :item_topic, class_name: "Topic"
    belongs_to :user
    belongs_to :post, optional: true

    validates :score,
              presence: true,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: MIN_SCORE,
                less_than_or_equal_to: MAX_SCORE,
              }
    validates :user_id, uniqueness: { scope: :item_topic_id }
  end
end

# == Schema Information
#
# Table name: kuu_rating_scores
#
#  id            :bigint           not null, primary key
#  score         :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  item_topic_id :integer          not null
#  post_id       :integer
#  user_id       :integer          not null
#
# Indexes
#
#  index_kuu_rating_scores_on_item_topic_id_and_user_id  (item_topic_id,user_id) UNIQUE
#  index_kuu_rating_scores_on_post_id                    (post_id) UNIQUE WHERE (post_id IS NOT NULL)
#  index_kuu_rating_scores_on_user_id_and_created_at     (user_id,created_at)
#
