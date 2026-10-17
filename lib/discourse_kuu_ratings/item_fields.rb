# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分主题和评分对象所在的分类，以及评分对象指向所属评分主题的自定义字段
  module ItemFields
    BOARD_TOPIC_ID = "kuu_board_topic_id"
    NAME_MAX_LENGTH = 30

    def self.board_category_id
      SiteSetting.kuu_ratings_board_category.to_i
    end

    def self.item_category_id
      SiteSetting.kuu_ratings_item_category.to_i
    end

    def self.item_category?(category_id)
      item_category_id > 0 && category_id.to_i == item_category_id
    end

    # 评分主题里已有的对象（不分大小写）和这些名称重名的
    def self.taken_names(board_topic_id, names)
      lowered = names.map(&:downcase)
      Topic
        .where(category_id: item_category_id)
        .where(
          id:
            TopicCustomField.where(name: BOARD_TOPIC_ID, value: board_topic_id.to_s).select(
              :topic_id,
            ),
        )
        .where("LOWER(topics.title) IN (?)", lowered)
        .pluck(:title)
    end

    def self.open_board?(board_topic_id, guardian)
      return false if board_category_id <= 0 || board_topic_id.to_i <= 0

      board =
        Topic.find_by(
          id: board_topic_id.to_i,
          category_id: board_category_id,
          visible: true,
          closed: false,
          archived: false,
        )
      board.present? && guardian.can_see?(board)
    end
  end
end
