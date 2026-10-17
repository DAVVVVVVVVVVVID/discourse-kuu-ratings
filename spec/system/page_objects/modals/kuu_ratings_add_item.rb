# frozen_string_literal: true

module PageObjects
  module Modals
    # 往已有评分主题添加一个评分对象
    class KuuRatingsAddItem < PageObjects::Modals::Base
      MODAL_SELECTOR = ".kuu-add-item-modal"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def fill_in(name:, image:)
        fields =
          PageObjects::Components::KuuRatingsItemFields.new(
            find("#{MODAL_SELECTOR} .kuu-item-fields"),
          )
        fields.fill_in_name(name)
        fields.upload_image(image)
        fields.has_image?
        self
      end

      def submit
        find("#{MODAL_SELECTOR} .kuu-add-item-modal__submit").click
      end

      def has_board?(board)
        has_css?(
          "#{MODAL_SELECTOR} .d-modal__header",
          text: I18n.t("js.kuu_ratings.add_item.board", title: board.title),
        )
      end

      def has_error?(message)
        has_css?("#{MODAL_SELECTOR} #modal-alert", text: message)
      end
    end
  end
end
