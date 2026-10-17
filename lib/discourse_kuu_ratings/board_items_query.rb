# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分主题下已上线、当前用户看得到的评分对象，按卡片列表的排序方式排好
  class BoardItemsQuery
    MAX_ITEMS = 200
    CARD_FIELDS = [RatingScore::AVG_FIELD, RatingScore::COUNT_FIELD].freeze
    AVG_SQL = "NULLIF(kuu_avg.value, '')::numeric"
    COUNT_SQL = "COALESCE(NULLIF(kuu_count.value, '')::integer, 0)"
    ORDERS = {
      "score" => "#{AVG_SQL} DESC NULLS LAST, #{COUNT_SQL} DESC, topics.created_at DESC",
      "count" => "#{COUNT_SQL} DESC, #{AVG_SQL} DESC NULLS LAST, topics.created_at DESC",
      "latest" => "topics.created_at DESC",
    }.freeze
    SORTS = ORDERS.keys.freeze

    def self.call(board_topic:, guardian:, sort:)
      Topic
        .secured(guardian)
        .where(category_id: ItemFields.item_category_id, visible: true)
        .joins(Topic.sanitize_sql_array([<<~SQL, board_topic_id: board_topic.id.to_s]))
          INNER JOIN topic_custom_fields kuu_board
            ON kuu_board.topic_id = topics.id
            AND kuu_board.name = '#{ItemFields::BOARD_TOPIC_ID}'
            AND kuu_board.value = :board_topic_id
          LEFT JOIN topic_custom_fields kuu_avg
            ON kuu_avg.topic_id = topics.id AND kuu_avg.name = '#{RatingScore::AVG_FIELD}'
          LEFT JOIN topic_custom_fields kuu_count
            ON kuu_count.topic_id = topics.id AND kuu_count.name = '#{RatingScore::COUNT_FIELD}'
        SQL
        .order(Arel.sql(ORDERS.fetch(sort)))
        .limit(MAX_ITEMS)
        .includes(:topic_thumbnails, :image_upload)
        .to_a
        .tap { |items| Topic.preload_custom_fields(items, CARD_FIELDS) }
    end
  end
end
