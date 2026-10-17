# frozen_string_literal: true

module DiscourseKuuRatings
  # 给评分对象打分，可选附一条短评（短评是评分对象帖子里的回帖，不经过审核）
  class RatingScore::Create
    include Service::Base

    params do
      attribute :item_topic_id, :integer
      # 不做类型转换：整数类型会把 "4.5"、"abc" 悄悄转成 4 和 0，校验就查不出来了
      attribute :stars
      attribute :comment, :string

      before_validation { self.comment = comment&.strip.presence }

      validates :item_topic_id, presence: true
      validates :stars, numericality: { only_integer: true, in: 1..RatingScore::MAX_STARS }
      validates :comment, length: { maximum: RatingScore::COMMENT_MAX_LENGTH }

      def score
        RatingScore.score_for_stars(Integer(stars))
      end
    end

    model :item_topic
    policy :can_see_item
    policy :can_score_item
    policy :board_accepts_scores
    policy :not_scored_yet
    only_if(:has_comment) do
      policy :comment_is_acceptable, class_name: RatingScore::Policy::CommentIsAcceptable
    end

    transaction do
      model :rating_score, :create_rating_score
      only_if(:has_comment) do
        model :comment_post, :create_comment_post
        step :attach_comment_to_rating_score
      end
      step :refresh_item_stats
    end

    private

    def fetch_item_topic(params:)
      Topic.find_by(id: params.item_topic_id, category_id: ItemFields.item_category_id)
    end

    def can_see_item(guardian:, item_topic:)
      guardian.can_see_topic?(item_topic)
    end

    # 短评跳过了 PostCreator 的校验，封禁检查也一起跳过了，所以在这里补上
    def can_score_item(guardian:, item_topic:)
      guardian.can_create_post_on_topic?(item_topic) && !guardian.user.suspended? &&
        item_topic.visible? && !item_topic.closed? && !item_topic.archived?
    end

    def board_accepts_scores(guardian:, item_topic:)
      ItemFields.open_board?(item_topic.custom_fields[ItemFields::BOARD_TOPIC_ID], guardian)
    end

    def not_scored_yet(guardian:, item_topic:)
      !RatingScore.exists?(item_topic:, user: guardian.user)
    end

    def has_comment(params:)
      params.comment.present?
    end

    def create_rating_score(guardian:, item_topic:, params:)
      RatingScore.create(item_topic:, user: guardian.user, score: params.score)
    end

    # 短评由插件自己校验长度和屏蔽词，不走 core 的回帖长度限制
    def create_comment_post(guardian:, item_topic:, params:)
      PostCreator.new(
        guardian.user,
        topic_id: item_topic.id,
        raw: params.comment,
        skip_validations: true,
      ).create
    end

    def attach_comment_to_rating_score(rating_score:, comment_post:)
      rating_score.update!(post: comment_post)
    end

    def refresh_item_stats(item_topic:)
      RatingScore.refresh_item_stats(item_topic)
    end
  end
end
