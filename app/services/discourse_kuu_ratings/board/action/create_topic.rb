# frozen_string_literal: true

module DiscourseKuuRatings
  # 以提交人的名义建评分主题。首帖是一句固定文字，评分主题页上不显示它
  class Board::Action::CreateTopic < Service::ActionBase
    option :user
    option :title

    # 跳过 core 校验：名称可能很短、可能和别的话题重名；普通用户也没有在评分分类发新话题的权限
    def call
      PostCreator.create!(
        user,
        title:,
        raw:
          I18n.with_locale(SiteSetting.default_locale) { I18n.t("kuu_ratings.board_first_post") },
        category: ItemFields.board_category_id,
        skip_validations: true,
      ).topic
    end
  end
end
