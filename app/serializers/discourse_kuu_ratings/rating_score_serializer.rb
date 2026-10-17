# frozen_string_literal: true

module DiscourseKuuRatings
  class RatingScoreSerializer < ApplicationSerializer
    attributes :id, :item_topic_id, :score, :post_id, :created_at
  end
end
