# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::BoardCards do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:empty_board) { Fabricate(:topic, category: board_category) }
  fab!(:other_topic, :topic)

  # 期望的卡片顺序：most_rated（3 人）> top_rated（2 人 10 分）> newer_tie > older_tie（都是 2 人 6 分，新的在前）
  # > unrated（没人打分，虽然最新也排最后，所以挤出前 4）
  fab!(:most_rated) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      scores: [8, 8, 8],
      created_at: 5.days.ago,
    )
  end
  fab!(:top_rated) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      scores: [10, 10],
      created_at: 4.days.ago,
    )
  end
  fab!(:older_tie) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      scores: [6, 6],
      created_at: 3.days.ago,
    )
  end
  fab!(:newer_tie) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      scores: [6, 6],
      created_at: 2.days.ago,
    )
  end
  fab!(:unrated) do
    Fabricate(:kuu_rating_item, category: item_category, board: board_topic, created_at: 1.day.ago)
  end
  # 打分最多，但被设为不可见，不算数也不显示
  fab!(:unlisted_item) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      visible: false,
      scores: [10, 10, 10, 10],
    )
  end

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  # 测试里 Fabricate(:category) 不建分类简介帖，要用时手动建
  def description_topic
    board_category.create_category_definition if board_category.topic.nil?
    board_category.reload.topic
  end

  def serialize(topic, guardian: user.guardian)
    TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json
  end

  def card_item_ids(card)
    card[:items].map { |item| item[:id] }
  end

  describe ".cards_for" do
    it "picks the first 4 items by score count, then average, then newest" do
      card = described_class.cards_for([board_topic], user.guardian)[board_topic.id]

      expect(card[:items].map(&:id)).to eq(
        [most_rated.id, top_rated.id, newer_tie.id, older_tie.id],
      )
    end

    it "puts unrated items last" do
      [most_rated, top_rated, older_tie].each(&:trash!)

      card = described_class.cards_for([board_topic], user.guardian)[board_topic.id]

      expect(card[:items].map(&:id)).to eq([newer_tie.id, unrated.id])
    end

    it "counts all visible items of the board" do
      card = described_class.cards_for([board_topic], user.guardian)[board_topic.id]

      expect(card[:item_count]).to eq(5)
    end

    it "gives a board without items an empty card" do
      expect(described_class.cards_for([empty_board], user.guardian)).to eq(
        empty_board.id => {
          item_count: 0,
          items: [],
        },
      )
    end

    it "loads the cards of several boards at once" do
      other_item = Fabricate(:kuu_rating_item, category: item_category, board: empty_board)

      cards = described_class.cards_for([board_topic, empty_board], user.guardian)

      expect(cards[board_topic.id][:item_count]).to eq(5)
      expect(cards[empty_board.id]).to eq(item_count: 1, items: [other_item])
    end

    it "gives no card to the category description topic" do
      expect(described_class.cards_for([description_topic], user.guardian)).to eq({})
    end

    context "when the user can not see the item category" do
      fab!(:group)
      fab!(:member) { Fabricate(:user, groups: [group]) }

      before { item_category.set_permissions(group => :full).tap { item_category.save! } }

      it "leaves out the items" do
        expect(described_class.cards_for([board_topic], user.guardian)[board_topic.id]).to eq(
          item_count: 0,
          items: [],
        )
        expect(described_class.cards_for([board_topic], Guardian.new)[board_topic.id]).to eq(
          item_count: 0,
          items: [],
        )
        expect(
          described_class.cards_for([board_topic], member.guardian)[board_topic.id][:item_count],
        ).to eq(5)
      end
    end
  end

  describe "the kuu_rating_board_card field of topic list items" do
    it "describes the top items of a board" do
      card = serialize(board_topic)[:kuu_rating_board_card]

      expect(card[:item_count]).to eq(5)
      expect(card_item_ids(card)).to eq([most_rated.id, top_rated.id, newer_tie.id, older_tie.id])
      expect(card[:items].first).to eq(
        id: most_rated.id,
        title: most_rated.title,
        fancy_title: most_rated.fancy_title,
        slug: most_rated.slug,
        url: most_rated.relative_url,
        image_url: nil,
        score_avg: 8.0,
        score_count: 3,
      )
    end

    it "gives the image url of items with an image" do
      most_rated.update!(image_upload: Fabricate(:image_upload))
      image_url = Topic.find(most_rated.id).image_url

      expect(image_url).to be_present
      expect(serialize(board_topic)[:kuu_rating_board_card][:items].first[:image_url]).to eq(
        image_url,
      )
    end

    it "describes a board without items" do
      expect(serialize(empty_board)[:kuu_rating_board_card]).to eq(item_count: 0, items: [])
    end

    it "uses the cards loaded for the topic list" do
      list = TopicQuery.new(user, category: board_category.id).list_latest
      json = TopicListSerializer.new(list, scope: user.guardian).as_json
      topics = json[:topic_list][:topics].index_by { |topic| topic[:id] }

      expect(topics[board_topic.id][:kuu_rating_board_card][:item_count]).to eq(5)
      expect(topics[empty_board.id][:kuu_rating_board_card]).to eq(item_count: 0, items: [])
    end

    it "is left out for other topics" do
      expect(serialize(other_topic)).not_to have_key(:kuu_rating_board_card)
      expect(serialize(most_rated)).not_to have_key(:kuu_rating_board_card)
    end

    it "is left out for the category description topic" do
      expect(serialize(description_topic)).not_to have_key(:kuu_rating_board_card)
    end

    context "when the plugin is disabled" do
      before { SiteSetting.kuu_ratings_enabled = false }

      it "is left out" do
        expect(serialize(board_topic)).not_to have_key(:kuu_rating_board_card)
      end
    end
  end
end
