# frozen_string_literal: true

module DiscourseKuuRatings
  # 以提交人的名义建评分对象：标题是名称，首帖就是那张图片
  class Item::Action::CreateTopic < Service::ActionBase
    option :user
    option :board_topic
    option :name
    option :upload

    # 跳过 core 校验：名称可能很短、可能和别的评分主题里的对象重名；普通用户也没有发新话题的权限
    def call
      PostCreator.create!(
        user,
        title: name,
        raw: UploadMarkdown.new(upload).image_markdown(display_name: name),
        category: ItemFields.item_category_id,
        skip_validations: true,
        topic_opts: {
          custom_fields: {
            ItemFields::BOARD_TOPIC_ID => board_topic.id,
          },
        },
      ).topic
    end
  end
end
