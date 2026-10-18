# frozen_string_literal: true

module DiscourseKuuRatings
  # 评分对象帖子里，直接回复对象的只能是短评（由打分接口直接用 PostCreator 发出）。
  # 普通发帖流程（网页、API、邮件）都经过 NewPostManager，在这里只放行对短评和回复的回复
  module ReplyRules
    def self.check(manager)
      return if !SiteSetting.kuu_ratings_enabled

      args = manager.args
      return if args[:topic_id].blank?
      return if !Topic.exists?(id: args[:topic_id], category_id: ItemFields.item_category_id)
      return if replying_to_review_thread?(args)

      failure(I18n.t("kuu_ratings.errors.reply_to_item_not_allowed"))
    end

    def self.replying_to_review_thread?(args)
      post_number = args[:reply_to_post_number].to_i
      # 被回复的短评已删除时也算楼中楼，由 create_thread_reply 给出「已删除」的提示
      post_number > 1 && Post.with_deleted.exists?(topic_id: args[:topic_id], post_number:)
    end

    # 楼中楼的回复（「+1」「同意」很常见）不受 core 回帖最短长度的限制，改用和短评一样的 1–500 字；
    # 其余检查照常：屏蔽词（NewPostManager 已查过）、新用户发链接和图片、重复内容等，
    # 需要审核时照常进审核队列。优先级最低，让其他插件（比如反垃圾）的 handler 先处理
    def self.create_thread_reply(manager)
      return if !SiteSetting.kuu_ratings_enabled

      args = manager.args
      topic = Topic.find_by(id: args[:topic_id], category_id: ItemFields.item_category_id)
      return if topic.nil?

      root_id = ReviewThreads.root_review_id(topic.id, args[:reply_to_post_number])
      return if root_id.nil?

      error = thread_reply_error(manager.user, topic, args, root_id)
      return failure(error) if error

      reason = NewPostManager.post_needs_approval?(manager)
      if reason == :skip
        create_post(manager)
      else
        manager.enqueue(reason, creator_opts: { skip_validations: true })
      end
    end

    def self.thread_reply_error(user, topic, args, root_id)
      if !user.guardian.can_create_post_on_topic?(topic) || user.silenced? || user.suspended?
        return I18n.t(:topic_not_found)
      end

      target = Post.find_by(topic_id: topic.id, post_number: args[:reply_to_post_number].to_i)
      # 短评被删除后楼里的回复保留，但这层楼不能再发新回复
      if target.nil? || !Post.exists?(id: root_id)
        return I18n.t("kuu_ratings.errors.review_deleted")
      end

      length = args[:raw].to_s.strip.length
      if length < 1 || length > ReviewThreads::REPLY_MAX_LENGTH
        return(I18n.t("kuu_ratings.errors.reply_length", max: ReviewThreads::REPLY_MAX_LENGTH))
      end

      post = Post.new(topic:, user:, raw: args[:raw])
      PostValidator.new(skip_post_body: true).validate(post)
      post.errors.full_messages.join(" ").presence
    end

    def self.create_post(manager)
      result = NewPostResult.new(:create_post)
      creator = PostCreator.new(manager.user, manager.args.merge(skip_validations: true))
      post = creator.create
      result.check_errors_from(creator)
      result.post = post if result.success?
      result
    end

    def self.failure(message)
      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, message)
      result
    end
  end
end
