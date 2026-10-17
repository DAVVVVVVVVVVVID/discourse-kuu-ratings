# frozen_string_literal: true

# 待审核的新评分主题。names 是对象名称，每个对象配一张提交人自己上传的图片
Fabricator(:kuu_board_submission, class_name: :reviewable_kuu_rating_submission) do
  transient :title, :names

  reviewable_by_moderator true
  created_by { Discourse.system_user }
  target_created_by { Fabricate(:user) }
  status { :pending }
  payload do |attrs|
    {
      "board_title" => attrs[:title] || "Ramen shops",
      "items" =>
        (attrs[:names] || %w[Ichiran Ippudo]).map do |name|
          { "name" => name, "upload_id" => Fabricate(:upload, user: attrs[:target_created_by]).id }
        end,
    }
  end
end

# 待审核的「往已有评分主题添加一个对象」
Fabricator(:kuu_item_submission, class_name: :reviewable_kuu_rating_submission) do
  transient :board, :name

  reviewable_by_moderator true
  created_by { Discourse.system_user }
  target_created_by { Fabricate(:user) }
  status { :pending }
  topic { |attrs| attrs[:board] }
  payload do |attrs|
    {
      "board_topic_id" => attrs[:board].id,
      "items" => [
        {
          "name" => attrs[:name] || "Ichiran",
          "upload_id" => Fabricate(:upload, user: attrs[:target_created_by]).id,
        },
      ],
    }
  end
end
