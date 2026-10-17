# frozen_string_literal: true

module PageObjects
  module Pages
    # 审核队列里插件自己的审核卡片（新建评分主题 / 添加评分对象）
    class KuuRatingsReview < PageObjects::Pages::Review
      def visit_queue
        page.visit("/review")
        self
      end

      def has_new_board_submission?(reviewable, title:, names:)
        within(reviewable_by_id(reviewable.id)) do
          has_css?(
            ".review-item__meta-label",
            text: I18n.t("js.kuu_ratings.reviewable.new_board"),
          ) && has_css?(".kuu-reviewable-submission__board-title", exact_text: title) &&
            has_item_names?(names)
        end
      end

      def has_add_item_submission?(reviewable, board:, names:)
        within(reviewable_by_id(reviewable.id)) do
          has_css?(
            ".review-item__meta-label",
            text: I18n.t("js.kuu_ratings.reviewable.add_to_board"),
          ) && has_css?(".review-item__meta-topic-title a", text: board.title) &&
            has_item_names?(names)
        end
      end

      def approve(reviewable)
        select_action(reviewable, "approve_kuu_rating_submission")
      end

      def reject(reviewable)
        select_action(reviewable, "reject_kuu_rating_submission")
      end

      def has_status?(reviewable, status)
        within(reviewable_by_id(reviewable.id)) do
          has_css?(
            ".review-item__status.--#{status}",
            text: I18n.t("js.review.statuses.#{status}.title"),
          )
        end
      end

      private

      def has_item_names?(names)
        has_css?(".kuu-reviewable-submission__name", count: names.size) &&
          names.all? { |name| has_css?(".kuu-reviewable-submission__name", exact_text: name) }
      end
    end
  end
end
