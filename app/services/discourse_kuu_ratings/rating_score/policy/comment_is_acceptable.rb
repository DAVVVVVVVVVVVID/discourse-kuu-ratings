# frozen_string_literal: true

module DiscourseKuuRatings
  # 短评发帖时跳过了 core 的正文检查（长度、内容质量、屏蔽词）。
  # 屏蔽词在这里补查，其余发帖限制（新用户发链接和图片、重复内容等）照常交给 PostValidator
  class RatingScore::Policy::CommentIsAcceptable < Service::PolicyBase
    delegate :params, :item_topic, to: :context, private: true

    def call
      errors.empty?
    end

    def reason
      errors.join(" ")
    end

    private

    def errors
      @errors ||= blocked_word_errors.presence || post_rule_errors
    end

    def blocked_word_errors
      words = WordWatcher.new(params.comment).should_block?
      return [] if words.blank?

      if words.size == 1
        [I18n.t("contains_blocked_word", word: CGI.escapeHTML(words.first))]
      else
        [I18n.t("contains_blocked_words", words: CGI.escapeHTML(words.join(", ")))]
      end
    end

    def post_rule_errors
      post = Post.new(topic: item_topic, user: guardian.user, raw: params.comment)
      PostValidator.new(skip_post_body: true).validate(post)
      post.errors.full_messages
    end
  end
end
