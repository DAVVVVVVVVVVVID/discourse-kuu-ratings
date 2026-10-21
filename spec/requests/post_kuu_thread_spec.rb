# frozen_string_literal: true

RSpec.describe "Review threads on posts in rating items" do
  fab!(:user)
  fab!(:replier) { Fabricate(:user, username: "replier", refresh_auto_groups: true) }
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

  let!(:review) do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    kuu_add_review(item_topic)
  end
  # replier 打了 6 分（短评必填以前的只打星数据，没有短评帖）；第二条回复的是第一条回复（楼里的回复），其余直接回复短评
  let!(:first_reply) do
    Fabricate(:kuu_rating_score, item_topic:, user: replier, score: 6)
    kuu_reply_to(review, user: replier)
  end
  let!(:reply_to_reply) { kuu_reply_to(first_reply) }
  let!(:third_reply) { kuu_reply_to(review) }
  let!(:fourth_reply) { kuu_reply_to(review) }

  def posts_in_topic
    get "/t/#{item_topic.id}.json"
    expect(response.status).to eq(200)
    response.parsed_body["post_stream"]["posts"].index_by { |post| post["id"] }
  end

  def thread_reply_ids(thread)
    thread["replies"].map { |reply| reply["id"] }
  end

  it "gives each review its thread with the first 3 replies" do
    posts = posts_in_topic

    thread = posts[review.id]["kuu_thread"]
    expect(thread).to include(
      "root_post_id" => review.id,
      "root_deleted" => false,
      "reply_count" => 4,
      "can_reply" => false,
    )
    expect(thread).not_to have_key("anchor")
    expect(thread_reply_ids(thread)).to eq([first_reply.id, reply_to_reply.id, third_reply.id])
    expect(posts[review.id]).not_to have_key("kuu_root_review_post_id")
    expect(posts[item_topic.first_post.id]).not_to include("kuu_thread", "kuu_root_review_post_id")
  end

  it "marks each reply with the review it belongs to" do
    posts = posts_in_topic

    expect(
      [first_reply, reply_to_reply, fourth_reply].map do |reply|
        posts[reply.id].values_at("kuu_root_review_post_id", "kuu_thread")
      end,
    ).to all(eq([review.id, nil]))
  end

  it "describes each reply in the thread" do
    PostActionCreator.like(user, first_reply)
    sign_in(user)

    replies = posts_in_topic[review.id]["kuu_thread"]["replies"].index_by { |reply| reply["id"] }

    expect(replies[first_reply.id]).to include(
      "post_number" => first_reply.post_number,
      "like_count" => 1,
      "liked" => true,
      "can_like" => true,
      "can_edit" => false,
      "can_delete" => false,
      "kuu_score" => 6,
    )
    expect(replies[first_reply.id]).not_to have_key("reply_to_username")
    expect(replies[first_reply.id]["user"]).to include("username" => "replier")
    expect(replies[reply_to_reply.id]).to include(
      "liked" => false,
      "kuu_score" => nil,
      "reply_to_username" => "replier",
    )
  end

  it "lets the author edit and delete their own reply" do
    sign_in(replier)

    reply = posts_in_topic[review.id]["kuu_thread"]["replies"].first

    expect(reply).to include("id" => first_reply.id, "can_edit" => true, "can_delete" => true)
  end

  it "lets a logged in user reply" do
    sign_in(user)

    expect(posts_in_topic[review.id]["kuu_thread"]["can_reply"]).to eq(true)
  end

  it "leaves deleted replies out of the thread" do
    first_reply.trash!

    thread = posts_in_topic[review.id]["kuu_thread"]

    expect(thread["reply_count"]).to eq(3)
    expect(thread_reply_ids(thread)).to eq([reply_to_reply.id, third_reply.id, fourth_reply.id])
  end

  context "when the review has been deleted" do
    before do
      review.trash!
      sign_in(user)
    end

    it "lets the first reply carry the thread" do
      posts = posts_in_topic

      expect(posts).not_to have_key(review.id)
      expect(posts[first_reply.id]["kuu_thread"]).to include(
        "root_post_id" => review.id,
        "root_deleted" => true,
        "can_reply" => false,
        "reply_count" => 4,
        "anchor" => true,
      )
      expect(posts[reply_to_reply.id]).not_to have_key("kuu_thread")
    end

    it "lets the next visible reply carry the thread when the first one is deleted too" do
      first_reply.trash!

      posts = posts_in_topic

      expect(posts[reply_to_reply.id]["kuu_thread"]).to include(
        "anchor" => true,
        "reply_count" => 3,
      )
      expect(posts[third_reply.id]).not_to have_key("kuu_thread")
    end
  end

  it "adds the thread to a single review" do
    get "/posts/#{review.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["kuu_thread"]).to include("reply_count" => 4)
    expect(thread_reply_ids(response.parsed_body["kuu_thread"])).to eq(
      [first_reply.id, reply_to_reply.id, third_reply.id],
    )
  end

  it "adds the review to a single reply" do
    get "/posts/#{reply_to_reply.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["kuu_root_review_post_id"]).to eq(review.id)
    expect(response.parsed_body).not_to have_key("kuu_thread")
  end

  it "does not add threads outside the item category" do
    other_topic = Fabricate(:topic_with_op)
    kuu_reply_to(other_topic.first_post)
    get "/t/#{other_topic.id}.json"

    expect(response.parsed_body["post_stream"]["posts"]).to all(
      exclude("kuu_thread", "kuu_root_review_post_id"),
    )
  end

  it "loads the threads of all reviews with a fixed number of queries" do
    serialize = -> do
      TopicViewSerializer.new(
        TopicView.new(item_topic.id, user),
        scope: user.guardian,
        root: false,
      ).as_json
    end
    PostActionCreator.like(user, first_reply)
    serialize.call

    queries_for_one_review = track_sql_queries { serialize.call }.size

    3.times do
      another_review = kuu_add_review(item_topic)
      reply = kuu_reply_to(another_review, user: Fabricate(:user))
      kuu_reply_to(reply)
      PostActionCreator.like(user, reply)
    end

    queries_for_four_reviews = track_sql_queries { serialize.call }.size

    expect(queries_for_four_reviews).to eq(queries_for_one_review)
  end
end
