# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::Board::ListItems do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_topic_id) }
    it { is_expected.to validate_inclusion_of(:sort).in_array(%w[score count latest]) }

    it "sorts by score by default" do
      expect(described_class.new.sort).to eq("score")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:reviewed_item) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        created_at: 2.days.ago,
      )
    end
    fab!(:quiet_item) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        created_at: 1.day.ago,
      )
    end
    fab!(:hot_review) { Fabricate(:kuu_review, item_topic: reviewed_item, like_count: 2) }
    fab!(:cold_review) { Fabricate(:kuu_review, item_topic: reviewed_item, like_count: 1) }

    let(:params) { { board_topic_id:, sort: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:board_topic_id) { board_topic.id }
    let(:sort) { "latest" }

    before do
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:sort) { "best" }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic is not in the board category" do
      let(:board_topic_id) { reviewed_item.id }

      it { is_expected.to fail_to_find_a_model(:board_topic) }
    end

    context "when the user cannot see the board" do
      before do
        # 子分类的权限不能比父分类宽，要先收紧子分类
        [item_category, board_category].each do |category|
          category.set_permissions(admins: :full)
          category.save!
        end
      end

      it { is_expected.to fail_a_policy(:can_see_board) }
    end

    context "when the board has no items" do
      fab!(:board_topic) { Fabricate(:topic, category: board_category) }

      it { is_expected.to run_successfully }

      it "returns no items and no hot reviews" do
        expect(result.items).to be_empty
        expect(result.hot_reviews).to eq({})
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns the items in the requested order" do
        expect(result.items).to eq([quiet_item, reviewed_item])
      end

      it "returns the most liked review of each item, keyed by item id" do
        expect(result.hot_reviews).to eq(reviewed_item.id => hot_review)
      end
    end
  end
end
