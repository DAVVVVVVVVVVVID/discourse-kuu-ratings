# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::BoardItemsQuery do
  describe ".call" do
    subject(:items) { described_class.call(board_topic:, guardian: user.guardian, sort:) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:other_board) { Fabricate(:topic, category: board_category) }
    # 创建时间和分数故意错开，让每种排序的每一级都起作用
    fab!(:top_rated) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        scores: [10],
        created_at: 5.days.ago,
      )
    end
    fab!(:popular) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        scores: [8, 8],
        created_at: 4.days.ago,
      )
    end
    fab!(:rated_once) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        scores: [8],
        created_at: 3.days.ago,
      )
    end
    fab!(:unrated) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        created_at: 1.day.ago,
      )
    end
    fab!(:other_board_item) do
      Fabricate(:kuu_rating_item, category: item_category, board: other_board)
    end
    fab!(:unlisted_item) do
      Fabricate(:kuu_rating_item, category: item_category, board: board_topic, visible: false)
    end
    fab!(:deleted_item) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        deleted_at: 1.hour.ago,
      )
    end
    fab!(:outside_item) do
      Fabricate(:kuu_rating_item, category: board_category, board: board_topic)
    end

    let(:sort) { "latest" }

    before do
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when sorting by latest" do
      it "returns only the listed items of the board, newest first" do
        expect(items).to eq([unrated, rated_once, popular, top_rated])
      end
    end

    context "when sorting by score" do
      let(:sort) { "score" }

      it "puts the best average first, more scores first on ties, and unrated items last" do
        expect(items).to eq([top_rated, popular, rated_once, unrated])
      end
    end

    context "when sorting by count" do
      let(:sort) { "count" }

      it "puts the most scored first, then the best average" do
        expect(items).to eq([popular, top_rated, rated_once, unrated])
      end
    end

    context "when the user cannot see the item category" do
      before do
        item_category.set_permissions(admins: :full)
        item_category.save!
      end

      it { is_expected.to be_empty }
    end

    context "with more items than the limit" do
      around { |example| stub_const(described_class, "MAX_ITEMS", 2) { example.run } }

      it "returns only the first items" do
        expect(items).to eq([unrated, rated_once])
      end
    end
  end
end
