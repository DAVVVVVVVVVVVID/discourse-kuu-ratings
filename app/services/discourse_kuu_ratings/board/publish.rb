# frozen_string_literal: true

module DiscourseKuuRatings
  # 新评分主题审核通过：建评分主题和里面的所有评分对象，通知提交人
  class Board::Publish
    include Service::Base

    params do
      attribute :reviewable_id, :integer

      validates :reviewable_id, presence: true
    end

    model :submission
    # 图片全被删时也交给 uploads_still_present，审核员才能看到具体原因
    model :uploads, optional: true
    policy :uploads_still_present

    try do
      transaction do
        model :board_topic, :create_board_topic
        step :create_item_topics
      end
    end

    step :notify_submitter

    private

    def fetch_submission(params:)
      ReviewableKuuRatingSubmission.pending.find_by(id: params.reviewable_id)
    end

    def fetch_uploads(submission:)
      submission.uploads_by_id
    end

    def uploads_still_present(submission:, uploads:)
      submission.uploads_present?(uploads)
    end

    def create_board_topic(submission:)
      Board::Action::CreateTopic.call(
        user: submission.target_created_by,
        title: submission.board_title,
      )
    end

    def create_item_topics(submission:, board_topic:, uploads:)
      submission.items.each do |item|
        Item::Action::CreateTopic.call(
          user: submission.target_created_by,
          board_topic:,
          name: item["name"],
          upload: uploads[item["upload_id"]],
        )
      end
    end

    def notify_submitter(submission:, board_topic:)
      Notification.create!(
        notification_type: Notification.types[:post_approved],
        user_id: submission.target_created_by_id,
        topic_id: board_topic.id,
        post_number: 1,
        data: { post_url: board_topic.relative_url }.to_json,
      )
    end
  end
end
