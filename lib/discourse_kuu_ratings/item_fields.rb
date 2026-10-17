# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象（topic）的自定义字段：发帖时校验，审核通过后写回
  module ItemFields
    BOARD_TOPIC_ID = "kuu_board_topic_id"
    TAGLINE = "kuu_tagline"
    NAMES = [BOARD_TOPIC_ID, TAGLINE].freeze
    TAGLINE_MAX_LENGTH = 40

    def self.board_category_id
      SiteSetting.kuu_ratings_board_category.to_i
    end

    def self.item_category_id
      SiteSetting.kuu_ratings_item_category.to_i
    end

    def self.item_category?(category_id)
      item_category_id > 0 && category_id.to_i == item_category_id
    end

    # 直接发帖时 opts 来自 controller（HashWithIndifferentAccess），
    # 进过审核队列的 opts 来自 JSON payload（字符串键），两种都要能读
    def self.from_creator_opts(opts)
      topic_opts = opts[:topic_opts] || opts["topic_opts"] || {}
      fields =
        opts[:custom_fields] || opts["custom_fields"] || topic_opts[:custom_fields] ||
          topic_opts["custom_fields"] || {}
      fields.to_h.stringify_keys.slice(*NAMES)
    end

    def self.validate(topic, creator)
      return if creator.opts[:reviewed_queued_post]
      return if !item_category?(topic.category_id)

      fields = from_creator_opts(creator.opts)
      errors = topic.errors

      if !open_board?(fields[BOARD_TOPIC_ID], creator.guardian)
        errors.add(:base, I18n.t("kuu_ratings.errors.board_invalid"))
      end

      tagline = fields[TAGLINE].to_s.strip
      if tagline.blank?
        errors.add(:base, I18n.t("kuu_ratings.errors.tagline_required"))
      elsif tagline.length > TAGLINE_MAX_LENGTH
        errors.add(:base, I18n.t("kuu_ratings.errors.tagline_too_long", count: TAGLINE_MAX_LENGTH))
      end

      if !has_image?(creator.opts[:raw])
        errors.add(:base, I18n.t("kuu_ratings.errors.image_required"))
      end
    end

    # 审核队列会丢掉 topic custom fields，审核通过后从 payload 里写回
    def self.restore_after_approval(reviewable, post)
      topic = post.topic
      return if !post.is_first_post? || !item_category?(topic.category_id)

      fields = from_creator_opts(reviewable.payload)
      return if fields.blank?

      fields[TAGLINE] = fields[TAGLINE].to_s.strip if fields.key?(TAGLINE)
      topic.custom_fields.merge!(fields)
      topic.save_custom_fields
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

    def self.has_image?(raw)
      return false if raw.blank?

      Nokogiri::HTML5
        .fragment(PrettyText.cook(raw))
        .css("img")
        .any? { |img| (img["class"].to_s.split & %w[emoji avatar]).empty? }
    end
  end
end
