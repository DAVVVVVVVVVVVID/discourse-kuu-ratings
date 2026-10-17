# frozen_string_literal: true

DiscourseKuuRatings::Engine.routes.draw do
  post "/boards" => "boards#create"
  get "/boards/:board_topic_id/items" => "items#index"
  post "/boards/:board_topic_id/items" => "items#create"
  get "/items/:item_topic_id" => "items#show"
  post "/items/:item_topic_id/score" => "scores#create"
  delete "/items/:item_topic_id/score" => "scores#destroy"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuRatings::Engine, at: "kuu-ratings" }
