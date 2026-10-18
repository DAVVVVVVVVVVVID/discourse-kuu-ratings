# frozen_string_literal: true

# 用户提交的评分主题（带至少 2 个对象），或往已有评分主题里添加的评分对象。
# 审核通过前帖子还不存在，内容都在 payload 里：
#   新建评分主题：{ "board_title" => "...", "items" => [{ "name" => "...", "upload_id" => 1 }, ...] }
#   添加评分对象：{ "board_topic_id" => 12, "items" => [{ "name" => "...", "upload_id" => 1 }] }
class ReviewableKuuRatingSubmission < Reviewable
  include ReviewableActionBuilder

  BOARD_MIN_ITEMS = 2
  BOARD_MAX_ITEMS = 20

  # 审核通过失败时，按哪个 policy 没通过给管理员看对应的原因
  PUBLISH_FAILURE_MESSAGES = {
    "board_accepts_items" => "kuu_ratings.errors.board_closed",
    "name_still_available" => "kuu_ratings.errors.name_taken",
    "uploads_still_present" => "kuu_ratings.errors.image_missing",
  }.freeze

  # 批准前图片没被任何帖子引用，不登记的话超过 clean_orphan_uploads_grace_period_hours 会被清理。
  # 处理完（批准、拒绝，或提交人被删除时 core 设成的忽略）就解除：批准后由新帖子引用，其他情况按孤儿文件清理
  after_save do
    if pending?
      UploadReference.ensure_exist!(upload_ids:, target: self) if saved_change_to_payload?
    elsif saved_change_to_status?
      release_uploads
    end
  end

  def self.submit!(submitter:, payload:, board_topic: nil)
    needs_review!(
      created_by: Discourse.system_user,
      target_created_by: submitter,
      topic: board_topic,
      reviewable_by_moderator: true,
      potential_spam: false,
      payload:,
    )
  end

  def serializer
    ReviewableKuuRatingSubmissionSerializer
  end

  def queue_for_review!
    add_score(Discourse.system_user, ReviewableScore.types[:needs_approval], force_review: true)
  end

  def uploads_by_id
    Upload.where(id: upload_ids).index_by(&:id)
  end

  # 提交后、审核前，图片可能已经被删掉
  def uploads_present?(uploads)
    uploads.size == upload_ids.uniq.size
  end

  def new_board?
    payload["board_topic_id"].blank?
  end

  def board_title
    payload["board_title"]
  end

  def board_topic_id
    payload["board_topic_id"]
  end

  def items
    payload["items"] || []
  end

  def upload_ids
    items.map { |item| item["upload_id"] }
  end

  def build_combined_actions(actions, _guardian, _args)
    return unless pending?

    # 提交人被删除后就没法以提交人的名义建帖，只能拒绝
    if target_created_by.present?
      build_action(actions, :approve_kuu_rating_submission, icon: "check")
    end
    build_action(actions, :reject_kuu_rating_submission, icon: "xmark")
  end

  # 失败时 Reviewable#perform 会回滚整个事务，已经建好的帖子不会留下
  def perform_approve_kuu_rating_submission(performed_by, _args)
    service = new_board? ? DiscourseKuuRatings::Board::Publish : DiscourseKuuRatings::Item::Publish
    result = service.call(params: { reviewable_id: id }, guardian: performed_by.guardian)

    return create_result(:failure) { |r| r.errors = publish_errors(result) } if result.failure?

    self.target = new_board? ? result[:board_topic] : result[:item_topic]
    save!
    create_result(:success, :approved)
  end

  def perform_reject_kuu_rating_submission(_performed_by, _args)
    if target_created_by.present?
      SystemMessage.create_from_system_user(
        target_created_by,
        :kuu_rating_submission_rejected,
        name: new_board? ? board_title : items.first&.dig("name"),
      )
    end
    create_result(:success, :rejected)
  end

  private

  # ensure_exist! 存的是子类名，where(target: self) 会按 STI 基类 Reviewable 查，找不到
  def release_uploads
    UploadReference.where(target_type: self.class.name, target_id: id).delete_all
  end

  def publish_errors(result)
    failed =
      PUBLISH_FAILURE_MESSAGES.find { |policy, _| result["result.policy.#{policy}"]&.failure? }
    ActiveModel::Errors
      .new(self)
      .tap do |errors|
        errors.add(:base, I18n.t(failed&.last || "kuu_ratings.errors.publish_failed"))
      end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score DESC,created_at DESC)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
