# frozen_string_literal: true

module PageObjects
  module Components
    # 新建评分主题、添加评分对象表单里的一个对象（图片 + 名称）
    class KuuRatingsItemFields < PageObjects::Components::Base
      def initialize(element)
        @element = element
      end

      def fill_in_name(name)
        @element.find(".kuu-item-fields__name input").fill_in(with: name)
        self
      end

      def upload_image(file)
        attach_file(file.path) { @element.find(".kuu-item-fields__image label.btn").click }
        self
      end

      def has_image?
        # 上传要走一次服务器，给足时间
        @element.has_css?(".kuu-item-fields__uploader.has-image", wait: 10)
      end

      def has_name_error?(message)
        @element.has_css?(".kuu-item-fields__name .form-kit__errors", text: message)
      end

      def has_image_error?(message)
        @element.has_css?(".kuu-item-fields__image .form-kit__errors", text: message)
      end

      def has_remove_button?
        @element.has_css?(".kuu-new-board-form__remove")
      end

      def remove
        @element.find(".kuu-new-board-form__remove").click
      end
    end
  end
end
