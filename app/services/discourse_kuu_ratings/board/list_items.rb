# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分主题页的卡片列表：主题下已上线的评分对象，带平均分、打分人数和第一条热评
  class Board::ListItems
    include Service::Base

    params do
      attribute :board_topic_id, :integer
      attribute :sort, :string, default: "score"

      validates :board_topic_id, presence: true
      validates :sort, inclusion: { in: BoardItemsQuery::SORTS }
    end

    model :board_topic
    policy :can_see_board
    model :items, optional: true
    model :hot_reviews, optional: true

    private

    def fetch_board_topic(params:)
      Topic.find_by(id: params.board_topic_id, category_id: ItemFields.board_category_id)
    end

    def can_see_board(guardian:, board_topic:)
      guardian.can_see_topic?(board_topic)
    end

    def fetch_items(guardian:, board_topic:, params:)
      BoardItemsQuery.call(board_topic:, guardian:, sort: params.sort)
    end

    def fetch_hot_reviews(items:)
      RatingScore.hot_reviews(items.map(&:id), per_item: 1).index_by(&:item_topic_id)
    end
  end
end
