# frozen_string_literal: true

module PageObjects
  module Modals
    # 新建评分主题：名称 + 2–20 个评分对象
    class KuuRatingsNewBoard < PageObjects::Modals::Base
      MODAL_SELECTOR = ".kuu-new-board-modal"
      ITEM_SELECTOR = "#{MODAL_SELECTOR} .kuu-new-board-form .kuu-item-fields".freeze

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def fill_in_title(title)
        find("#{MODAL_SELECTOR} .form-kit__field[data-name='title'] input").fill_in(with: title)
        self
      end

      # index 从 0 开始
      def item(index)
        PageObjects::Components::KuuRatingsItemFields.new(
          all(ITEM_SELECTOR, minimum: index + 1)[index],
        )
      end

      def fill_in_item(index, name:, image: nil)
        fields = item(index)
        fields.fill_in_name(name)
        if image
          fields.upload_image(image)
          fields.has_image?
        end
        self
      end

      def click_add_item
        find("#{MODAL_SELECTOR} .kuu-new-board-form__add").click
        self
      end

      def submit
        find("#{MODAL_SELECTOR} .kuu-new-board-modal__submit").click
      end

      def has_items?(count:)
        has_css?(ITEM_SELECTOR, count:)
      end

      def has_add_item_button?
        has_css?("#{MODAL_SELECTOR} .kuu-new-board-form__add")
      end

      def has_no_add_item_button?
        has_no_css?("#{MODAL_SELECTOR} .kuu-new-board-form__add")
      end

      def has_remove_buttons?(count:)
        has_css?("#{MODAL_SELECTOR} .kuu-new-board-form__remove", count:)
      end

      def has_no_remove_buttons?
        has_no_css?("#{MODAL_SELECTOR} .kuu-new-board-form__remove")
      end

      def has_title_error?(message)
        has_css?(
          "#{MODAL_SELECTOR} .form-kit__field[data-name='title'] .form-kit__errors",
          text: message,
        )
      end

      def has_error?(message)
        has_css?("#{MODAL_SELECTOR} #modal-alert", text: message)
      end
    end
  end
end
