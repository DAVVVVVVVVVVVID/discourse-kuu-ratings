# frozen_string_literal: true

Fabricator(:kuu_rating_score, from: "DiscourseKuuRatings::RatingScore") do
  item_topic { Fabricate(:topic) }
  user
  score 8
end
