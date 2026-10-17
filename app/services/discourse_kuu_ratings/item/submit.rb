# frozen_string_literal: true

module DiscourseKuuRatings
  # 往已有的评分主题里添加一个评分对象（图片 + 名称），进审核队列
  class Item::Submit
    include Service::Base

    params do
      attribute :board_topic_id, :integer
      attribute :name, :string
      attribute :upload_id, :integer

      # 名称会写进首帖的图片 Markdown，换行会跳出图片语法、注入 @提及和链接
      before_validation { self.name = name&.squish }

      validates :board_topic_id, :upload_id, presence: true
      validates :name, presence: true, length: { maximum: ItemFields::NAME_MAX_LENGTH }

      def names
        [name]
      end

      def upload_ids
        [upload_id]
      end
    end

    model :board_topic
    policy :can_see_board
    policy :board_accepts_items
    policy :submitter_is_active, class_name: Submission::Policy::SubmitterIsActive
    policy :name_available
    policy :no_blocked_words, class_name: Submission::Policy::NoBlockedWords
    model :uploads
    policy :own_images, class_name: Submission::Policy::OwnImages

    transaction do
      model :submission, :create_submission
      step :queue_for_review
    end

    private

    def fetch_board_topic(params:)
      Topic.find_by(id: params.board_topic_id, category_id: ItemFields.board_category_id)
    end

    def can_see_board(guardian:, board_topic:)
      guardian.can_see_topic?(board_topic)
    end

    def board_accepts_items(guardian:, board_topic:)
      ItemFields.open_board?(board_topic.id, guardian)
    end

    def name_available(board_topic:, params:)
      ItemFields.taken_names(board_topic.id, params.names).empty?
    end

    def fetch_uploads(params:)
      Upload.where(id: params.upload_ids).to_a
    end

    def create_submission(guardian:, board_topic:, params:)
      ReviewableKuuRatingSubmission.submit!(
        submitter: guardian.user,
        board_topic:,
        payload: {
          board_topic_id: board_topic.id,
          items: [{ name: params.name, upload_id: params.upload_id }],
        },
      )
    end

    def queue_for_review(submission:)
      submission.queue_for_review!
    end
  end
end
