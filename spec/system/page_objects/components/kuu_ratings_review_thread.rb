# frozen_string_literal: true

module PageObjects
  module Components
    # 一条短评下面的楼中楼（短评被删除时显示在楼里第一条回复的位置）
    class KuuRatingsReviewThread < PageObjects::Components::Base
      def initialize(review)
        @selector = ".kuu-review-thread[data-root-post-id='#{review.id}']"
      end

      def not_shown?
        has_no_css?(@selector)
      end

      # 楼里正好是这些回复，按顺序
      def has_replies?(*replies)
        has_css?("#{@selector} .kuu-review-reply", count: replies.size) &&
          replies.each_with_index.all? do |reply, index|
            has_css?(
              "#{@selector} .kuu-review-reply:nth-child(#{index + 1})[data-post-number='#{reply.post_number}']",
            )
          end
      end

      def has_reply_count?(count)
        has_css?("#{@selector} .kuu-review-reply", count:)
      end

      def has_reply?(user, text)
        has_css?("#{@selector} .kuu-review-reply", text:) &&
          within(find("#{@selector} .kuu-review-reply", text:)) do
            has_css?(".kuu-review-reply__username", exact_text: user.username)
          end
      end

      def has_reply_to?(text, user)
        has_css?("#{@selector} .kuu-review-reply", text:) &&
          within(find("#{@selector} .kuu-review-reply", text:)) do
            has_css?(
              ".kuu-review-reply__reply-to",
              exact_text: I18n.t("js.kuu_ratings.thread.reply_to", username: user.username),
            )
          end
      end

      def has_view_all_button?(count)
        has_css?(
          "#{@selector} .kuu-review-thread__more",
          exact_text: I18n.t("js.kuu_ratings.thread.view_all", count:),
        )
      end

      def has_view_more_button?
        has_css?(
          "#{@selector} .kuu-review-thread__more",
          exact_text: I18n.t("js.kuu_ratings.thread.view_more"),
        )
      end

      def has_no_more_button?
        has_no_css?("#{@selector} .kuu-review-thread__more")
      end

      def click_more
        find("#{@selector} .kuu-review-thread__more").click
        self
      end

      def click_reply_on(reply)
        find("#{reply_selector(reply)} .kuu-review-reply__reply").click
        self
      end

      def has_reply_input?
        has_css?("#{@selector} .kuu-reply-input textarea:focus")
      end

      def has_no_reply_input?
        has_no_css?("#{@selector} .kuu-reply-input")
      end

      def send_reply(text)
        find("#{@selector} .kuu-reply-input textarea").fill_in(with: text)
        find("#{@selector} .kuu-reply-input__submit").click
        self
      end

      def toggle_like(reply)
        find("#{reply_selector(reply)} .kuu-review-reply__like").click
        self
      end

      def has_liked_reply?(reply, count:)
        has_css?(
          "#{reply_selector(reply)} .kuu-review-reply__like.--liked[aria-pressed='true']",
          exact_text: count.to_s,
        )
      end

      def has_unliked_reply?(reply, count:)
        has_css?(
          "#{reply_selector(reply)} .kuu-review-reply__like:not(.--liked)[aria-pressed='false']",
          exact_text: count.to_s,
        )
      end

      def has_deleted_notice?
        has_css?(
          "#{@selector} .kuu-review-thread__deleted",
          text: I18n.t("js.kuu_ratings.thread.review_deleted"),
        )
      end

      def has_no_reply_buttons?
        has_css?("#{@selector} .kuu-review-reply") &&
          has_no_css?("#{@selector} .kuu-review-reply__reply")
      end

      def has_highlighted_reply?(reply)
        has_css?("#{reply_selector(reply)}.--highlighted") &&
          has_css?("#{@selector} .kuu-review-reply.--highlighted", count: 1)
      end

      private

      def reply_selector(reply)
        "#{@selector} .kuu-review-reply[data-post-number='#{reply.post_number}']"
      end
    end
  end
end
