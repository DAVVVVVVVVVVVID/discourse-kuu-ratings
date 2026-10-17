# frozen_string_literal: true

DiscourseKuuRatings::Engine.routes.draw do
  # 接口在这里定义，见技术方案第 5 节
end

Discourse::Application.routes.draw { mount ::DiscourseKuuRatings::Engine, at: "kuu-ratings" }
