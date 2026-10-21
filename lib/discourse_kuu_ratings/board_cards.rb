# frozen_string_literal: true

module DiscourseKuuRatings
  # 帖子列表里评分主题显示成卡片用（Issue #4）：标题下面一排最多 ITEMS_PER_CARD 个对象。
  # 一页列表的所有评分主题一次查完，结果挂在 topic 上给 TopicListItemSerializer 用
  module BoardCards
    ITEMS_PER_CARD = 4
    # 打分人数多的在前；人数相同平均分高的在前；都一样新的在前。没人打分的排最后
    ORDER =
      "#{BoardItemsQuery::COUNT_SQL} DESC, #{BoardItemsQuery::AVG_SQL} DESC NULLS LAST, topics.created_at DESC"

    def self.board?(topic)
      SiteSetting.kuu_ratings_enabled && ItemFields.board_category_id > 0 &&
        topic.category_id == ItemFields.board_category_id
    end

    # TopicList.on_preload 里调用
    def self.preload(topics, guardian)
      boards = topics.select { |topic| board?(topic) }
      return if boards.empty?

      cards = cards_for(boards, guardian)
      boards.each { |board| board.kuu_board_card = cards[board.id] }
    end

    # 返回 { board_id => card }。分类的简介帖也在评分分类里，但它不是评分主题，不给卡片
    def self.cards_for(boards, guardian)
      board_ids = boards.map(&:id) - Category.where(topic_id: boards.map(&:id)).pluck(:topic_id)
      return {} if board_ids.empty?

      counts = BoardItemsQuery.scope(board_ids, guardian).group("kuu_board.value").count
      items = top_items(board_ids, guardian).group_by(&:kuu_board_id)

      board_ids.index_with do |board_id|
        { item_count: counts.fetch(board_id.to_s, 0), items: items.fetch(board_id, []) }
      end
    end

    # 序列化器用：一般已经由 preload 查好；没经过 TopicList 的帖子单独查一次
    def self.serialized_card(topic, guardian)
      card =
        if topic.instance_variable_defined?(:@kuu_board_card)
          topic.kuu_board_card
        else
          cards_for([topic], guardian)[topic.id]
        end
      card_json(card, guardian)
    end

    def self.card_json(card, guardian)
      return if card.nil?

      {
        item_count: card[:item_count],
        items:
          ActiveModel::ArraySerializer.new(
            card[:items],
            each_serializer: ItemSerializer,
            scope: guardian,
          ).as_json,
      }
    end

    def self.top_items(board_ids, guardian)
      ranked =
        BoardItemsQuery.scope(board_ids, guardian).select(
          "topics.*",
          "kuu_board.value::integer AS kuu_board_id",
          "ROW_NUMBER() OVER (PARTITION BY kuu_board.value ORDER BY #{ORDER}) AS kuu_card_rank",
        )

      Topic
        .from(ranked, :topics)
        .select("topics.*")
        .where("kuu_card_rank <= ?", ITEMS_PER_CARD)
        .order(:kuu_board_id, :kuu_card_rank)
        .includes(:topic_thumbnails, :image_upload)
        .to_a
        .tap { |items| Topic.preload_custom_fields(items, BoardItemsQuery::CARD_FIELDS) }
    end
  end
end
