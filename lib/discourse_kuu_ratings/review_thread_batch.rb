# frozen_string_literal: true

module DiscourseKuuRatings
  # 一次查好若干条短评的楼中楼数据（前几条回复、回复数、我赞过哪些、回复人的打分、「回复 @某人」），
  # 帖子页和「点击查看」都用它，避免每条回复各查一次
  class ReviewThreadBatch
    attr_reader :guardian

    # replies 不传时取每条短评的前 ReviewThreads::PREVIEW_SIZE 条
    def initialize(item_topic_id:, root_ids:, guardian:, replies: nil)
      @item_topic_id = item_topic_id
      @root_ids = root_ids.uniq
      @guardian = guardian
      @replies_by_root = replies ? replies.group_by { |reply| root_id_of(reply) } : nil
    end

    def replies_for(root_id)
      replies_by_root.fetch(root_id, [])
    end

    def reply_count(root_id)
      reply_counts.fetch(root_id, 0)
    end

    def root_deleted?(root_id)
      !live_root_ids.include?(root_id)
    end

    def liked?(post_id)
      liked_post_ids.include?(post_id)
    end

    def score_for(user_id)
      scores_by_user_id[user_id]
    end

    # 回复楼里的某条回复时显示「回复 @用户名：」；直接回复短评时不显示
    def reply_to_username(reply)
      root_number = root_post_numbers[root_id_of(reply)]
      return if reply.reply_to_post_number.blank? || reply.reply_to_post_number == root_number

      reply.reply_to_user&.username
    end

    def thread_json(root_id)
      {
        root_post_id: root_id,
        root_deleted: root_deleted?(root_id),
        reply_count: reply_count(root_id),
        can_reply: can_reply?(root_id),
        replies:
          ActiveModel::ArraySerializer.new(
            replies_for(root_id),
            each_serializer: ReviewReplySerializer,
            scope: guardian,
            thread_batch: self,
          ).as_json,
      }
    end

    private

    def replies_by_root
      @replies_by_root ||= ReviewThreads.preview_replies(@root_ids, guardian)
    end

    def all_replies
      @all_replies ||=
        replies_by_root.values.flatten.tap do |replies|
          ActiveRecord::Associations::Preloader.new(
            records: replies,
            associations: %i[user reply_to_user],
          ).call
        end
    end

    def root_id_of(reply)
      reply.try(:kuu_root_id) || ReviewThreads.root_id_of(reply)
    end

    def reply_counts
      @reply_counts ||= ReviewThreads.reply_counts(@root_ids, guardian)
    end

    def live_root_ids
      @live_root_ids ||= Post.where(id: @root_ids).pluck(:id).to_set
    end

    def root_post_numbers
      @root_post_numbers ||= Post.with_deleted.where(id: @root_ids).pluck(:id, :post_number).to_h
    end

    def liked_post_ids
      @liked_post_ids ||=
        if guardian.user
          PostAction
            .where(
              user_id: guardian.user.id,
              post_id: all_replies.map(&:id),
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )
            .pluck(:post_id)
            .to_set
        else
          Set.new
        end
    end

    def scores_by_user_id
      @scores_by_user_id ||=
        RatingScore
          .where(item_topic_id: @item_topic_id, user_id: all_replies.map(&:user_id))
          .pluck(:user_id, :score)
          .to_h
    end

    def can_reply?(root_id)
      return false if guardian.user.nil? || root_deleted?(root_id)

      @topic ||= Topic.find_by(id: @item_topic_id)
      guardian.can_create_post_on_topic?(@topic)
    end
  end
end
