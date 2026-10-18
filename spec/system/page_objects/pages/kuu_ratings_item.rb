# frozen_string_literal: true

module PageObjects
  module Pages
    # 评分对象页：概要、打分区、热评，下面是短评（帖子）
    class KuuRatingsItem < PageObjects::Pages::Base
      def visit_item(item)
        page.visit(item.relative_url)
        has_css?(".kuu-item .kuu-score-panel")
        self
      end

      def has_hidden_first_post?
        has_css?("body.kuu-item-topic") &&
          has_css?(".topic-post[data-post-number='1']", visible: :hidden)
      end

      def has_board_link?(board)
        has_css?(".kuu-item__board[href='#{board.relative_url}']", text: board.title)
      end

      def has_summary?(score:, count:)
        has_css?(".kuu-item__score-value", exact_text: score) &&
          has_css?(
            ".kuu-item__score-count",
            text: I18n.t("js.kuu_ratings.board.score_count", count:),
          )
      end

      def has_no_scores?
        has_css?(".kuu-item__no-score", text: I18n.t("js.kuu_ratings.board.no_scores"))
      end

      # 分布条从 5 星排到 1 星
      def has_star_count?(stars:, count:)
        has_css?(
          ".kuu-item__distribution-row:nth-child(#{6 - stars}) .kuu-item__distribution-count",
          exact_text: count.to_s,
        )
      end

      def pick_stars(stars)
        find(".kuu-star-input__star:nth-child(#{stars})").click
        self
      end

      def fill_in_comment(comment)
        find(".kuu-score-panel__form textarea").fill_in(with: comment)
        self
      end

      def submit_score
        find(".kuu-score-panel__submit").click
        self
      end

      def has_score_form?
        has_css?(".kuu-score-panel__form .kuu-star-input")
      end

      def has_no_score_form?
        has_no_css?(".kuu-score-panel__form")
      end

      def has_my_score?(score)
        has_css?(".kuu-score-panel__mine-text", text: I18n.t("js.kuu_ratings.score.mine", score:))
      end

      def has_no_my_score?
        has_no_css?(".kuu-score-panel__mine")
      end

      def delete_my_score
        find(".kuu-score-panel__delete").click
        self
      end

      def has_notice?(key)
        has_css?(".kuu-score-panel__notice", text: I18n.t("js.kuu_ratings.score.#{key}"))
      end

      def has_scoring_focused?
        has_css?(".kuu-star-input__star:focus")
      end

      def has_hot_reviews?(*reviews)
        has_css?(".kuu-hot-review", count: reviews.size) &&
          reviews.each_with_index.all? do |review, index|
            has_css?(
              ".kuu-hot-review:nth-child(#{index + 1}) .kuu-hot-review__username",
              exact_text: review.user.username,
            )
          end
      end

      def visit_post(post)
        page.visit(post.url)
        has_css?(".kuu-item .kuu-score-panel")
        self
      end

      def review_thread(review)
        PageObjects::Components::KuuRatingsReviewThread.new(review)
      end

      # 帖子流里显示的帖子（楼中楼的回复不在这里显示）
      def has_post_in_stream?(post)
        has_css?(".topic-post #post_#{post.post_number}", visible: true)
      end

      def has_no_post_in_stream?(post)
        has_no_css?(".topic-post #post_#{post.post_number}", visible: true)
      end

      def has_hot_review_reply_count?(review, count:)
        has_css?(".kuu-hot-review", text: review.user.username) &&
          within(find(".kuu-hot-review", text: review.user.username)) do
            has_css?(".kuu-hot-review__replies", exact_text: count.to_s)
          end
      end

      def has_review_post?(user, comment, score:)
        has_css?(".topic-post:not([data-post-number='1'])", text: comment) &&
          within(find(".topic-post:not([data-post-number='1'])", text: comment)) do
            has_css?(".names", text: user.username) &&
              has_css?(
                ".kuu-post-score[title='#{I18n.t("js.kuu_ratings.score.post_score", score:)}']",
              )
          end
      end

      def has_no_review_post?(comment)
        has_no_css?(".topic-post", text: comment)
      end

      def has_start_scoring_button?
        has_css?("#topic-footer-buttons .kuu-start-scoring-button") &&
          has_no_css?("#topic-footer-buttons .topic-footer-main-buttons .create", visible: true)
      end

      def click_start_scoring
        find("#topic-footer-buttons .kuu-start-scoring-button").click
        self
      end

      def click_timeline_reply
        find(".timeline-footer-controls .reply-to-post").click
        self
      end
    end
  end
end
