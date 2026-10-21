# frozen_string_literal: true

RSpec.describe "Rating board cards in topic lists" do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic_with_op, category: board_category) }
  fab!(:item_topic) do
    Fabricate(:kuu_rating_item, category: item_category, board: board_topic, scores: [8, 6])
  end
  fab!(:other_topic, :topic_with_op)

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def listed_topics
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].index_by { |topic| topic["id"] }
  end

  def expect_board_card(topic_json)
    expect(topic_json["kuu_rating_board_card"]).to eq(
      "item_count" => 1,
      "items" => [
        {
          "id" => item_topic.id,
          "title" => item_topic.title,
          "fancy_title" => item_topic.fancy_title,
          "slug" => item_topic.slug,
          "url" => item_topic.relative_url,
          "image_url" => nil,
          "score_avg" => 7.0,
          "score_count" => 2,
        },
      ],
    )
  end

  it "gives boards a card on the latest list" do
    get "/latest.json"

    topics = listed_topics
    expect_board_card(topics[board_topic.id])
    expect(topics[other_topic.id]).not_to have_key("kuu_rating_board_card")
  end

  it "gives boards a card on the board category page" do
    get "/c/#{board_category.slug}/#{board_category.id}.json"

    expect_board_card(listed_topics[board_topic.id])
  end

  it "loads the cards with a fixed number of queries" do
    # 线上的对象图片都有生成好的缩略图，image_url 优先用缩略图
    add_item = ->(board) do
      upload = Fabricate(:image_upload)
      width, height = Topic.share_thumbnail_size
      TopicThumbnail.create!(
        upload:,
        max_width: width,
        max_height: height,
        optimized_image: Fabricate(:optimized_image, upload:),
      )
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board:,
        scores: [10],
        image_upload: upload,
      )
    end
    # 第一次序列化会补算 fancy_title 等，只数第二次
    count_queries = -> do
      serialize =
        lambda do
          TopicListSerializer.new(
            TopicQuery.new(user, category: board_category.id).list_latest,
            scope: user.guardian,
          ).as_json
        end
      serialize.call
      cards = nil
      count =
        track_sql_queries do
          cards = serialize.call[:topic_list][:topics].filter_map { _1[:kuu_rating_board_card] }
        end.size
      [count, cards.size]
    end
    add_item.call(board_topic)

    queries_for_one_board, card_count = count_queries.call
    expect(card_count).to eq(1)

    2.times { add_item.call(Fabricate(:topic_with_op, category: board_category)) }

    queries_for_three_boards, card_count = count_queries.call
    expect(card_count).to eq(3)
    expect(queries_for_three_boards).to eq(queries_for_one_board)
  end

  # 帖子底部的推荐也是帖子列表，评分主题同样显示成卡片
  it "gives boards a card in the suggested topics" do
    get "/t/#{other_topic.id}.json"

    expect(response.status).to eq(200)
    suggested = response.parsed_body["suggested_topics"].index_by { |topic| topic["id"] }
    expect_board_card(suggested.fetch(board_topic.id))
  end

  context "when the plugin is disabled" do
    before { SiteSetting.kuu_ratings_enabled = false }

    it "gives boards no card" do
      get "/latest.json"

      expect(listed_topics[board_topic.id]).not_to have_key("kuu_rating_board_card")
    end
  end
end
