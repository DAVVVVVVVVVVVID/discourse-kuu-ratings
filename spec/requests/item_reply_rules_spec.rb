# frozen_string_literal: true

RSpec.describe "Replies in rating items" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
  fab!(:review_post) { Fabricate(:post, topic: item_topic) }

  let(:raw) { "I agree, the broth is really rich here." }
  let(:reply_params) { { topic_id: item_topic.id, raw: } }
  let(:error_message) { I18n.t("kuu_ratings.errors.reply_to_item_not_allowed") }
  let(:deleted_message) { I18n.t("kuu_ratings.errors.review_deleted") }
  let(:root_field) { DiscourseKuuRatings::ReviewThreads::ROOT_FIELD }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    sign_in(user)
  end

  def expect_rejected(message = error_message)
    expect { post "/posts.json", params: reply_params }.not_to change { Post.count }
    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to contain_exactly(message)
  end

  def reply_to(target, raw: "+1")
    post "/posts.json",
         params: {
           topic_id: target.topic_id,
           reply_to_post_number: target.post_number,
           raw:,
           nested_post: true,
         }
  end

  def created_reply
    Post.find(response.parsed_body.dig("post", "id"))
  end

  it "rejects a reply to the item itself" do
    expect_rejected
  end

  it "rejects a reply to the first post" do
    reply_params[:reply_to_post_number] = 1
    expect_rejected
  end

  it "rejects a reply to a post that does not exist" do
    reply_params[:reply_to_post_number] = 99
    expect_rejected
  end

  it "tells the user a deleted review can no longer be replied to" do
    review_post.trash!
    reply_params[:reply_to_post_number] = review_post.post_number
    expect_rejected(deleted_message)
  end

  it "applies to staff too" do
    sign_in(admin)
    expect_rejected
  end

  it "allows a reply to a short review" do
    reply_params[:reply_to_post_number] = review_post.post_number

    post "/posts.json", params: reply_params

    expect(response.status).to eq(200)
    expect(Post.last).to have_attributes(
      topic_id: item_topic.id,
      reply_to_post_number: review_post.post_number,
    )
  end

  it "allows a reply to a reply" do
    reply = Fabricate(:post, topic: item_topic, reply_to_post_number: review_post.post_number)
    reply_params[:reply_to_post_number] = reply.post_number

    post "/posts.json", params: reply_params

    expect(response.status).to eq(200)
  end

  it "still allows posting a short review through the score endpoint" do
    post "/kuu-ratings/items/#{item_topic.id}/score.json", params: { stars: 4, comment: "好吃" }

    expect(response.status).to eq(201)
    expect(item_topic.posts.last).to have_attributes(raw: "好吃", reply_to_post_number: nil)
  end

  it "does not affect creating a new topic in the item category" do
    post "/posts.json",
         params: {
           title: "Another ramen shop near campus",
           raw: "Thin noodles and light broth, worth a visit.",
           category: item_category.id,
         }

    expect(response.status).to eq(200)
  end

  it "does not affect replies in other categories" do
    other_topic = Fabricate(:topic_with_op)

    post "/posts.json", params: { topic_id: other_topic.id, raw: }

    expect(response.status).to eq(200)
  end

  it "does not apply when the plugin is disabled" do
    SiteSetting.kuu_ratings_enabled = false

    post "/posts.json", params: reply_params

    expect(response.status).to eq(200)
  end

  # 楼中楼的回复：长度 1–500，不受 core 回帖最短长度限制，其余发帖限制照常
  describe "replies in a review thread" do
    before { SiteSetting.min_post_length = 8 }

    it "allows a reply shorter than the minimum post length and puts it in the thread" do
      reply_to(review_post)

      expect(response.status).to eq(200)
      expect(response.parsed_body["action"]).to eq("create_post")
      expect(created_reply).to have_attributes(
        raw: "+1",
        reply_to_post_number: review_post.post_number,
      )
      expect(created_reply.custom_fields[root_field]).to eq(review_post.id)
    end

    it "puts a reply to a reply in the thread of the review" do
      reply = kuu_reply_to(review_post)

      reply_to(reply)

      expect(response.status).to eq(200)
      expect(created_reply.custom_fields[root_field]).to eq(review_post.id)
    end

    it "accepts a reply of exactly 500 characters" do
      reply_to(review_post, raw: "好" * 500)

      expect(response.status).to eq(200)
    end

    it "rejects a reply longer than 500 characters" do
      expect { reply_to(review_post, raw: "好" * 501) }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("kuu_ratings.errors.reply_length", max: 500),
      )
    end

    it "rejects a reply to a reply in the thread of a deleted review" do
      reply = kuu_reply_to(review_post)
      review_post.trash!

      expect { reply_to(reply) }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(deleted_message)
    end

    it "rejects a reply to a deleted reply" do
      reply = kuu_reply_to(review_post)
      reply.trash!

      expect { reply_to(reply) }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(deleted_message)
    end

    it "rejects a reply with a blocked word" do
      Fabricate(:watched_word, word: "rubbish", action: WatchedWord.actions[:block])

      expect { reply_to(review_post, raw: "rubbish") }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("contains_blocked_word", word: "rubbish"),
      )
    end

    it "keeps the other posting limits, such as links from new users" do
      sign_in(Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true))
      SiteSetting.newuser_max_links = 0

      expect { reply_to(review_post, raw: "see https://example.com/ramen") }.not_to change {
        Post.count
      }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(I18n.t(:no_links_allowed))
    end

    it "rejects a reply from a silenced user" do
      user.update!(silenced_till: 1.year.from_now)

      expect { reply_to(review_post) }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(I18n.t(:topic_not_found))
    end

    it "queues a reply from a user who needs approval and puts it in the thread once approved" do
      SiteSetting.approve_post_count = 5

      expect { reply_to(review_post) }.to change { ReviewableQueuedPost.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["action"]).to eq("enqueued")
      expect(Post.where(topic: item_topic, raw: "+1")).to be_empty

      result = ReviewableQueuedPost.last.perform(admin, :approve_post)

      expect(result.created_post).to have_attributes(
        raw: "+1",
        reply_to_post_number: review_post.post_number,
      )
      expect(result.created_post.custom_fields[root_field]).to eq(review_post.id)
    end

    it "keeps the minimum post length in other categories" do
      other_topic = Fabricate(:topic_with_op)

      expect { reply_to(other_topic.first_post) }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        "Body is too short (minimum is 8 characters)",
      )
    end

    it "keeps the minimum post length when the plugin is disabled" do
      SiteSetting.kuu_ratings_enabled = false

      expect { reply_to(review_post) }.not_to change { Post.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        "Body is too short (minimum is 8 characters)",
      )
    end
  end
end
