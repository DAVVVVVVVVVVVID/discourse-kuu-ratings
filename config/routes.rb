# frozen_string_literal: true

DiscourseKuuRatings::Engine.routes.draw do
  post "/items/:item_topic_id/score" => "scores#create"
  delete "/items/:item_topic_id/score" => "scores#destroy"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuRatings::Engine, at: "kuu-ratings" }
