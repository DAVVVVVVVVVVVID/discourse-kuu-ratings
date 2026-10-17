# frozen_string_literal: true

Fabricator(:kuu_rating_score, from: "DiscourseKuuRatings::RatingScore") do
  item_topic { Fabricate(:topic) }
  user
  score 8
end

# 带短评的打分：短评是评分对象里打分人发的回帖，like_count 是短评的赞数
Fabricator(:kuu_review, from: :kuu_rating_score) do
  transient :like_count

  post do |attrs|
    Fabricate(
      :post,
      topic: attrs[:item_topic],
      user: attrs[:user],
      like_count: attrs[:like_count] || 0,
    )
  end
end
