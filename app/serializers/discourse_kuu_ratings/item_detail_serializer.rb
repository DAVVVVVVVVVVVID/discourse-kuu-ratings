# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象页头部；所属评分主题、能否打分、分布、我的打分、热评由调用方查好，通过 options 传入
  class ItemDetailSerializer < ItemSerializer
    attributes :closed, :board_topic_id, :board, :accepts_scores, :can_score, :star_counts

    has_one :my_rating_score, serializer: RatingScoreSerializer, embed: :objects
    has_many :hot_reviews, serializer: ReviewSerializer, embed: :objects

    def board_topic_id
      object.custom_fields[ItemFields::BOARD_TOPIC_ID]
    end

    def board
      board_topic = @options[:board_topic]
      { id: board_topic.id, title: board_topic.title, url: board_topic.relative_url }
    end

    def include_board?
      @options[:board_topic].present?
    end

    def accepts_scores
      @options[:accepts_scores]
    end

    def can_score
      @options[:can_score]
    end

    # 1–5 星都返回，没人选的星级为 0，前端画分布条时不用补齐
    def star_counts
      (1..RatingScore::MAX_STARS).to_h { |stars| [stars, @options[:star_counts][stars] || 0] }
    end

    def my_rating_score
      @options[:my_rating_score]
    end

    def include_my_rating_score?
      @options[:my_rating_score].present?
    end

    def hot_reviews
      @options[:hot_reviews]
    end
  end
end
