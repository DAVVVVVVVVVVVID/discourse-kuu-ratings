# frozen_string_literal: true

# 评分对象：带首帖的 topic，用 kuu_board_topic_id 指向所属的评分主题。
# scores 传分数数组时会建好这些打分并重算统计
Fabricator(:kuu_rating_item, from: :topic_with_op) do
  transient :board, :scores

  after_create do |topic, transients|
    if transients[:board]
      topic.custom_fields[DiscourseKuuRatings::ItemFields::BOARD_TOPIC_ID] = transients[:board].id
    end
    topic.save_custom_fields

    if transients[:scores].present?
      transients[:scores].each { |score| Fabricate(:kuu_rating_score, item_topic: topic, score:) }
      DiscourseKuuRatings::RatingScore.refresh_item_stats(topic)
    end
  end
end
