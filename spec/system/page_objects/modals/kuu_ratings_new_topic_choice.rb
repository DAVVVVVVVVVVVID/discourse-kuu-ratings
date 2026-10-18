# frozen_string_literal: true

module PageObjects
  module Modals
    # 点「新建话题」后选择发普通话题还是评分主题（选择框由 discourse-kuu-new-topic 提供）
    class KuuRatingsNewTopicChoice < PageObjects::Modals::Base
      MODAL_SELECTOR = ".kuu-new-topic-choice"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def choose_topic
        find("#{MODAL_SELECTOR} .kuu-new-topic-choice__option.--topic").click
      end

      def choose_board
        find(
          "#{MODAL_SELECTOR} .kuu-new-topic-choice__option[data-type-id='kuu-ratings-board']",
        ).click
      end
    end
  end
end
