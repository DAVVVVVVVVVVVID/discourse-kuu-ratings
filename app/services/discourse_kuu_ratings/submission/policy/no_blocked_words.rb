# frozen_string_literal: true

module DiscourseKuuRatings
  # 插件建帖时跳过了 core 的校验，名称里的屏蔽词要在这里查
  class Submission::Policy::NoBlockedWords < Service::PolicyBase
    delegate :params, to: :context, private: true

    def call
      blocked_words.empty?
    end

    def reason
      if blocked_words.size == 1
        I18n.t("contains_blocked_word", word: CGI.escapeHTML(blocked_words.first))
      else
        I18n.t("contains_blocked_words", words: CGI.escapeHTML(blocked_words.join(", ")))
      end
    end

    private

    def blocked_words
      @blocked_words ||= WordWatcher.new(params.names.join(" ")).should_block? || []
    end
  end
end
