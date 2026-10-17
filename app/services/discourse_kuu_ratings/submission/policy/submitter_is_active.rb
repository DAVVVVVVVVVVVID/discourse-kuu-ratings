# frozen_string_literal: true

module DiscourseKuuRatings
  # 提交评分主题或评分对象的人必须已登录、没被禁言、没被封禁
  class Submission::Policy::SubmitterIsActive < Service::PolicyBase
    def call
      user = guardian.user
      user.present? && !user.silenced? && !user.suspended?
    end

    def reason
      I18n.t("kuu_ratings.errors.cannot_submit")
    end
  end
end
