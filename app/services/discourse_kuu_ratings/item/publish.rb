# frozen_string_literal: true

module DiscourseKuuRatings
  # 添加的评分对象审核通过：再确认一遍评分主题还开着、名称没被占用，然后建帖，通知提交人
  class Item::Publish
    include Service::Base

    params do
      attribute :reviewable_id, :integer

      validates :reviewable_id, presence: true
    end

    model :submission
    model :board_topic
    policy :board_accepts_items
    policy :name_still_available
    # 图片全被删时也交给 uploads_still_present，审核员才能看到具体原因
    model :uploads, optional: true
    policy :uploads_still_present

    try { transaction { model :item_topic, :create_item_topic } }

    step :notify_submitter

    private

    def fetch_submission(params:)
      ReviewableKuuRatingSubmission.pending.find_by(id: params.reviewable_id)
    end

    def fetch_board_topic(submission:)
      Topic.find_by(id: submission.board_topic_id, category_id: ItemFields.board_category_id)
    end

    def board_accepts_items(guardian:, board_topic:)
      ItemFields.open_board?(board_topic.id, guardian)
    end

    # 提交后、审核前，可能已经有同名的对象被批准了
    def name_still_available(submission:, board_topic:)
      ItemFields.taken_names(board_topic.id, submission.items.map { |item| item["name"] }).empty?
    end

    def fetch_uploads(submission:)
      submission.uploads_by_id
    end

    def uploads_still_present(submission:, uploads:)
      submission.uploads_present?(uploads)
    end

    def create_item_topic(submission:, board_topic:, uploads:)
      item = submission.items.first
      Item::Action::CreateTopic.call(
        user: submission.target_created_by,
        board_topic:,
        name: item["name"],
        upload: uploads[item["upload_id"]],
      )
    end

    def notify_submitter(submission:, item_topic:)
      Notification.create!(
        notification_type: Notification.types[:post_approved],
        user_id: submission.target_created_by_id,
        topic_id: item_topic.id,
        post_number: 1,
        data: { post_url: item_topic.relative_url }.to_json,
      )
    end
  end
end
