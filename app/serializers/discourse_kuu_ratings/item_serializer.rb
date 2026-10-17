# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象（topic）的基本信息，卡片和详情共用
  class ItemSerializer < ApplicationSerializer
    attributes :id,
               :title,
               :fancy_title,
               :slug,
               :url,
               :image_url,
               :score_avg,
               :score_count

    def url
      object.relative_url
    end

    def score_avg
      object.custom_fields[RatingScore::AVG_FIELD]&.to_f
    end

    def score_count
      object.custom_fields[RatingScore::COUNT_FIELD].to_i
    end
  end
end
