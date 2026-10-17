# frozen_string_literal: true

DiscourseKuuRatings::Engine.routes.draw do
  get "/boards/:board_topic_id/items" => "items#index"
  get "/items/:item_topic_id" => "items#show"
  post "/items/:item_topic_id/score" => "scores#create"
  delete "/items/:item_topic_id/score" => "scores#destroy"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuRatings::Engine, at: "kuu-ratings" }
