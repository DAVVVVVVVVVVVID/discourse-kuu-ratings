# frozen_string_literal: true

# 楼中楼的测试数据：短评走打分接口的服务发出，回复走 PostCreator（会触发 :post_created，写入所属短评）
module KuuRatingsThreadHelpers
  def kuu_add_review(item_topic, user: Fabricate(:user), stars: 4, comment: "Rich broth")
    result =
      DiscourseKuuRatings::RatingScore::Create.call(
        params: {
          item_topic_id: item_topic.id,
          stars:,
          comment:,
        },
        guardian: user.guardian,
      )
    raise "could not add the review: #{result.inspect_steps}" if result.failure?

    result.comment_post
  end

  def kuu_reply_to(post, user: Fabricate(:user), raw: "Agreed with this")
    PostCreator.create!(
      user,
      topic_id: post.topic_id,
      reply_to_post_number: post.post_number,
      raw:,
      skip_validations: true,
    )
  end
end

RSpec.configure { |config| config.include KuuRatingsThreadHelpers }
