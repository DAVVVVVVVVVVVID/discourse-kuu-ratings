# frozen_string_literal: true

module PageObjects
  module Pages
    # 评分主题页：标题下面是评分对象横条列表
    class KuuRatingsBoard < PageObjects::Pages::Base
      ITEM_SELECTOR = ".kuu-board-items .kuu-board-item"

      def visit_board(board)
        page.visit(board.relative_url)
        has_css?(".kuu-board-items")
        self
      end

      def has_hidden_first_post?
        has_css?("body.kuu-board-topic") &&
          has_css?(".topic-post[data-post-number='1']", visible: :hidden)
      end

      def has_item?(item, score:, count:)
        within(item_row(item)) do
          has_css?(".kuu-star-rating") &&
            has_css?(".kuu-board-item__score-value", exact_text: score) &&
            has_css?(
              ".kuu-board-item__score-count",
              text: I18n.t("js.kuu_ratings.board.score_count", count:),
            )
        end
      end

      def has_unscored_item?(item)
        within(item_row(item)) do
          has_css?(".kuu-board-item__no-score", text: I18n.t("js.kuu_ratings.board.no_scores")) &&
            has_no_css?(".kuu-star-rating")
        end
      end

      def has_hot_review?(item, review)
        within(item_row(item)) do
          has_css?(".kuu-board-item__review-user", text: review.user.username) &&
            has_css?(".kuu-board-item__review-text", text: review.post.raw)
        end
      end

      def has_no_hot_review?(item)
        within(item_row(item)) { has_no_css?(".kuu-board-item__review") }
      end

      def has_items_in_order?(*items)
        has_no_css?(".kuu-board-items .loading-spinner") &&
          has_css?(ITEM_SELECTOR, count: items.size) &&
          items.each_with_index.all? do |item, index|
            has_css?(
              "#{ITEM_SELECTOR}:nth-child(#{index + 1}) .kuu-board-item__name",
              exact_text: item.title,
            )
          end
      end

      def sort_by(sort)
        find(".kuu-board-items__sort", text: I18n.t("js.kuu_ratings.board.sorts.#{sort}")).click
        has_css?(
          ".kuu-board-items__sort.--active",
          text: I18n.t("js.kuu_ratings.board.sorts.#{sort}"),
        )
        self
      end

      def click_item(item)
        item_row(item).find(".kuu-board-item__link").click
      end

      def click_add_item
        find(".kuu-add-item-button").click
        PageObjects::Modals::KuuRatingsAddItem.new
      end

      def has_add_item_button?
        has_css?(".kuu-add-item-button")
      end

      def has_no_add_item_button?
        has_css?(".kuu-board-items") && has_no_css?(".kuu-add-item-button")
      end

      private

      def item_row(item)
        find(ITEM_SELECTOR, text: item.title)
      end
    end
  end
end
