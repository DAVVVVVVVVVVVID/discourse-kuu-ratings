# frozen_string_literal: true

module PageObjects
  module Components
    # 帖子列表里一个评分主题的卡片：标题下面一排评分对象，最右边「查看更多」
    class KuuRatingsBoardCard < PageObjects::Components::Base
      ITEM_SELECTOR = ".kuu-board-card__item:not(.--more)"

      def initialize(board)
        @board = board
        @selector = ".topic-list-item[data-topic-id='#{board.id}']"
      end

      def shown?
        has_css?("#{@selector}.kuu-rating-board .kuu-board-card") &&
          has_css?("#{@selector} a.title.raw-topic-link", exact_text: @board.title)
      end

      def not_shown?
        has_css?(@selector) && has_no_css?("#{@selector} .kuu-board-card")
      end

      def has_items_in_order?(*items)
        has_css?("#{@selector} #{ITEM_SELECTOR}", count: items.size) &&
          items.each_with_index.all? do |item, index|
            has_css?(
              "#{@selector} #{ITEM_SELECTOR}:nth-child(#{index + 1}) " \
                ".kuu-board-card__link[href='#{item.relative_url}'] .kuu-board-card__name",
              exact_text: item.title,
            )
          end
      end

      def has_item?(item, score:)
        within(item_element(item)) do
          has_css?(".kuu-board-card__score:not(.--none) .d-icon-star") &&
            has_css?(".kuu-board-card__score", exact_text: score)
        end
      end

      def has_unscored_item?(item)
        within(item_element(item)) do
          has_css?(
            ".kuu-board-card__score.--none",
            exact_text: I18n.t("js.kuu_ratings.board.no_scores"),
          )
        end
      end

      def has_item_image?(item, src:)
        within(item_element(item)) do
          has_css?(".kuu-board-card__image img") &&
            find(".kuu-board-card__image img")[:src].end_with?(src)
        end
      end

      def has_item_image_icon?(item)
        within(item_element(item)) do
          has_css?(".kuu-board-card__image .d-icon-image") &&
            has_no_css?(".kuu-board-card__image img")
        end
      end

      def has_more_link?
        has_css?(
          "#{@selector} .kuu-board-card__item.--more a.kuu-board-card__more[href='#{@board.relative_url}']",
          text: I18n.t("js.kuu_ratings.board_card.more"),
        )
      end

      # 一排对象放不下时可以左右滑动，页面本身不被撑宽
      def scrolls_sideways_within_page?
        has_css?("#{@selector} .kuu-board-card__items") && page.evaluate_script(<<~JS)
            (() => {
              const items = document.querySelector(#{"#{@selector} .kuu-board-card__items".to_json});
              return items.scrollWidth > items.clientWidth &&
                document.documentElement.scrollWidth <= window.innerWidth + 1;
            })()
          JS
      end

      def click_item(item)
        item_element(item).find(".kuu-board-card__link").click
      end

      def click_more
        find("#{@selector} .kuu-board-card__more").click
      end

      def click_title
        find("#{@selector} a.title.raw-topic-link").click
      end

      private

      def item_element(item)
        find("#{@selector} #{ITEM_SELECTOR}", text: item.title)
      end
    end
  end
end
