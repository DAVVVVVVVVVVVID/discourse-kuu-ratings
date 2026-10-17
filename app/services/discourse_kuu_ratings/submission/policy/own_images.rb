# frozen_string_literal: true

module DiscourseKuuRatings
  # 每个评分对象的图片都必须是提交人自己上传的图片
  class Submission::Policy::OwnImages < Service::PolicyBase
    delegate :params, :uploads, to: :context, private: true

    def call
      uploads.size == params.upload_ids.uniq.size &&
        uploads.all? do |upload|
          upload.user_id == guardian.user.id && FileHelper.is_supported_image?(upload.original_filename)
        end
    end

    def reason
      I18n.t("kuu_ratings.errors.image_invalid")
    end
  end
end
