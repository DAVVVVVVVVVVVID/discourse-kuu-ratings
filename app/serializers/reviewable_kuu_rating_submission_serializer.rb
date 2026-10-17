# frozen_string_literal: true

require_dependency "reviewable_serializer"

class ReviewableKuuRatingSubmissionSerializer < ReviewableSerializer
  payload_attributes :board_title, :board_topic_id
  attributes :items

  def items
    uploads = Upload.where(id: object.upload_ids).index_by(&:id)
    object.items.map { |item| { name: item["name"], image_url: uploads[item["upload_id"]]&.url } }
  end
end
