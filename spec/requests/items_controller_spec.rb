# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::ItemsController do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) do
    Fabricate(
      :kuu_rating_item,
      category: item_category,
      board: board_topic,
      tagline: "Tonkotsu ramen",
      created_at: 2.days.ago,
    )
  end
  fab!(:quiet_item) do
    Fabricate(:kuu_rating_item, category: item_category, board: board_topic, created_at: 1.day.ago)
  end
  fab!(:review) { Fabricate(:kuu_review, item_topic:, score: 10, like_count: 2) }

  let(:card_keys) do
    %w[
      id
      title
      fancy_title
      slug
      url
      image_url
      tagline
      score_avg
      score_count
      created_at
      closed
      hot_review
    ]
  end
  let(:review_keys) { %w[post_id post_number score like_count cooked created_at user] }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    DiscourseKuuRatings::RatingScore.refresh_item_stats(item_topic)
  end

  describe "#index" do
    let(:items_path) { "/kuu-ratings/boards/#{board_topic.id}/items.json" }

    it "returns the item cards to guests" do
      get items_path

      expect(response.status).to eq(200)
      cards = response.parsed_body["items"]
      expect(cards.map { |card| card["id"] }).to eq([item_topic.id, quiet_item.id])
      expect(cards.map(&:keys)).to all(match_array(card_keys))
      expect(cards.first).to include(
        "title" => item_topic.title,
        "url" => item_topic.relative_url,
        "tagline" => "Tonkotsu ramen",
        "score_avg" => 10.0,
        "score_count" => 1,
        "closed" => false,
      )
      expect(cards.first["hot_review"].keys).to match_array(review_keys)
      expect(cards.first["hot_review"]).to include(
        "post_id" => review.post_id,
        "score" => 10,
        "like_count" => 2,
      )
      expect(cards.first["hot_review"]["user"]).to include("username" => review.user.username)
      expect(cards.second).to include("score_avg" => nil, "score_count" => 0, "hot_review" => nil)
    end

    context "with a sort" do
      it "orders the cards by it" do
        get items_path, params: { sort: "latest" }

        expect(response.parsed_body["items"].map { |card| card["id"] }).to eq(
          [quiet_item.id, item_topic.id],
        )
      end
    end

    context "with an invalid sort" do
      it "returns a 400" do
        get items_path, params: { sort: "best" }

        expect(response.status).to eq(400)
      end
    end

    # 关闭评分主题只是停止打分，对象仍然可以浏览
    context "when the board is closed" do
      before { board_topic.update!(closed: true) }

      it "still returns the item cards" do
        get items_path

        expect(response.status).to eq(200)
        expect(response.parsed_body["items"].map { |card| card["id"] }).to contain_exactly(
          item_topic.id,
          quiet_item.id,
        )
      end
    end

    context "when the board does not exist" do
      let(:items_path) { "/kuu-ratings/boards/#{item_topic.id}/items.json" }

      it "returns a 404" do
        get items_path

        expect(response.status).to eq(404)
      end
    end

    context "when the user cannot see the board" do
      before do
        # 子分类的权限不能比父分类宽，要先收紧子分类
        [item_category, board_category].each do |category|
          category.set_permissions(admins: :full)
          category.save!
        end
        sign_in(user)
      end

      it "returns a 404" do
        get items_path

        expect(response.status).to eq(404)
      end
    end

    context "when the plugin is disabled" do
      before { SiteSetting.kuu_ratings_enabled = false }

      it "returns a 404" do
        get items_path

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#show" do
    let(:item_path) { "/kuu-ratings/items/#{item_topic.id}.json" }

    it "returns the item details to guests" do
      get item_path

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "id" => item_topic.id,
        "board_topic_id" => board_topic.id,
        "tagline" => "Tonkotsu ramen",
        "score_avg" => 10.0,
        "score_count" => 1,
        "star_counts" => {
          "1" => 0,
          "2" => 0,
          "3" => 0,
          "4" => 0,
          "5" => 1,
        },
      )
      expect(response.parsed_body).not_to have_key("my_rating_score")
      expect(response.parsed_body["hot_reviews"].map { |hot| hot["post_id"] }).to eq(
        [review.post_id],
      )
    end

    context "when the user has scored the item" do
      fab!(:my_score) { Fabricate(:kuu_rating_score, item_topic: quiet_item, user:, score: 4) }

      let(:item_path) { "/kuu-ratings/items/#{quiet_item.id}.json" }

      before { sign_in(user) }

      it "includes the user's score" do
        get item_path

        expect(response.parsed_body["my_rating_score"]).to include(
          "id" => my_score.id,
          "score" => 4,
          "post_id" => nil,
        )
      end
    end

    context "when the item has no scores" do
      let(:item_path) { "/kuu-ratings/items/#{quiet_item.id}.json" }

      it "returns empty stats" do
        get item_path

        expect(response.parsed_body).to include(
          "score_avg" => nil,
          "score_count" => 0,
          "star_counts" => {
            "1" => 0,
            "2" => 0,
            "3" => 0,
            "4" => 0,
            "5" => 0,
          },
          "hot_reviews" => [],
        )
      end
    end

    context "when the item does not exist" do
      let(:item_path) { "/kuu-ratings/items/#{board_topic.id}.json" }

      it "returns a 404" do
        get item_path

        expect(response.status).to eq(404)
      end
    end

    context "when the user cannot see the item" do
      before do
        item_category.set_permissions(admins: :full)
        item_category.save!
        sign_in(user)
      end

      it "returns a 404" do
        get item_path

        expect(response.status).to eq(404)
      end
    end

    context "when the plugin is disabled" do
      before { SiteSetting.kuu_ratings_enabled = false }

      it "returns a 404" do
        get item_path

        expect(response.status).to eq(404)
      end
    end
  end
end
