# frozen_string_literal: true

# 评分对象：带首帖的 topic，并用 kuu_board_topic_id 指向所属的评分主题
Fabricator(:kuu_rating_item, from: :topic_with_op) do
  transient :board

  after_create do |topic, transients|
    if transients[:board]
      topic.custom_fields[DiscourseKuuRatings::ItemFields::BOARD_TOPIC_ID] = transients[:board].id
      topic.save_custom_fields
    end
  end
end
