# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象页头部：所属评分主题、平均分、打分人数、星级分布、我的打分、前 3 条热评，
  # 以及现在能不能打分
  class Item::Show
    include Service::Base

    HOT_REVIEWS_LIMIT = 3

    params do
      attribute :item_topic_id, :integer

      validates :item_topic_id, presence: true
    end

    model :item_topic
    policy :can_see_item
    model :board_topic, optional: true
    step :check_scoring
    model :star_counts, optional: true
    model :my_rating_score, optional: true
    model :hot_reviews, optional: true

    private

    def fetch_item_topic(params:)
      Topic.includes(:topic_thumbnails, :image_upload).find_by(
        id: params.item_topic_id,
        category_id: ItemFields.item_category_id,
      )
    end

    def can_see_item(guardian:, item_topic:)
      guardian.can_see_topic?(item_topic)
    end

    def fetch_board_topic(guardian:, item_topic:)
      board =
        Topic.find_by(
          id: item_topic.custom_fields[ItemFields::BOARD_TOPIC_ID].to_i,
          category_id: ItemFields.board_category_id,
        )
      board if board && guardian.can_see_topic?(board)
    end

    # 和 RatingScore::Create 的 can_score_item、board_accepts_scores 保持一致
    def check_scoring(guardian:, item_topic:)
      context[:accepts_scores] = item_topic.visible? && !item_topic.closed? &&
        !item_topic.archived? &&
        ItemFields.open_board?(item_topic.custom_fields[ItemFields::BOARD_TOPIC_ID], guardian)
      context[:can_score] = context[:accepts_scores] && guardian.user.present? &&
        !guardian.user.suspended? && guardian.can_create_post_on_topic?(item_topic)
    end

    def fetch_star_counts(item_topic:)
      RatingScore
        .where(item_topic:)
        .group(:score)
        .count
        .transform_keys { |score| score / RatingScore::POINTS_PER_STAR }
    end

    def fetch_my_rating_score(guardian:, item_topic:)
      RatingScore.find_by(item_topic:, user: guardian.user)
    end

    def fetch_hot_reviews(item_topic:)
      RatingScore.hot_reviews([item_topic.id], per_item: HOT_REVIEWS_LIMIT).to_a
    end
  end
end
