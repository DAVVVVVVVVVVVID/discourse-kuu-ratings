# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::Item::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:item_topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
    fab!(:my_score) { Fabricate(:kuu_rating_score, item_topic:, user:, score: 8) }
    fab!(:first_review) { Fabricate(:kuu_review, item_topic:, score: 10, like_count: 4) }
    fab!(:second_review) { Fabricate(:kuu_review, item_topic:, score: 10, like_count: 3) }
    fab!(:third_review) { Fabricate(:kuu_review, item_topic:, score: 6, like_count: 2) }
    fab!(:fourth_review) { Fabricate(:kuu_review, item_topic:, score: 2, like_count: 1) }

    let(:params) { { item_topic_id: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:item_topic_id) { item_topic.id }

    before do
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:item_topic_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic is not in the item category" do
      let(:item_topic_id) { board_topic.id }

      it { is_expected.to fail_to_find_a_model(:item_topic) }
    end

    context "when the user cannot see the item" do
      before do
        item_category.set_permissions(admins: :full)
        item_category.save!
      end

      it { is_expected.to fail_a_policy(:can_see_item) }
    end

    context "when the board has been deleted" do
      before { board_topic.trash! }

      it { is_expected.to run_successfully }

      it "has no board and does not accept scores" do
        expect(result.board_topic).to be_nil
        expect(result.accepts_scores).to eq(false)
        expect(result.can_score).to eq(false)
      end
    end

    context "when the board topic is no longer in the board category" do
      before { board_topic.update!(category: Fabricate(:category)) }

      it "has no board and does not accept scores" do
        expect(result.board_topic).to be_nil
        expect(result.accepts_scores).to eq(false)
      end
    end

    context "when the user cannot see the board" do
      before do
        board_topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
        SiteSetting.kuu_ratings_board_category = board_topic.category_id
      end

      it "has no board and does not accept scores" do
        expect(result.board_topic).to be_nil
        expect(result.accepts_scores).to eq(false)
      end
    end

    context "when the board is closed" do
      before { board_topic.update!(closed: true) }

      it "still links the board but does not accept scores" do
        expect(result.board_topic).to eq(board_topic)
        expect(result.accepts_scores).to eq(false)
        expect(result.can_score).to eq(false)
      end
    end

    context "when the item is closed" do
      before { item_topic.update!(closed: true) }

      it "does not accept scores" do
        expect(result.accepts_scores).to eq(false)
        expect(result.can_score).to eq(false)
      end
    end

    context "when the item is unlisted" do
      before { item_topic.update!(visible: false) }

      it "does not accept scores" do
        expect(result.accepts_scores).to eq(false)
      end
    end

    # 游客没有可以 fabricate 的用户，只能换 guardian
    context "when not logged in" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to run_successfully }

      it "accepts scores but not from the viewer" do
        expect(result.accepts_scores).to eq(true)
        expect(result.can_score).to eq(false)
        expect(result.my_rating_score).to be_nil
      end
    end

    context "when the user is suspended" do
      fab!(:user) { Fabricate(:user, suspended_at: 1.day.ago, suspended_till: 1.year.from_now) }

      it "does not let the user score" do
        expect(result.accepts_scores).to eq(true)
        expect(result.can_score).to eq(false)
      end
    end

    context "when the user is silenced" do
      fab!(:user) { Fabricate(:user, silenced_till: 1.year.from_now) }

      it "does not let the user score" do
        expect(result.can_score).to eq(false)
      end
    end

    context "when the item has no scores" do
      fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

      it { is_expected.to run_successfully }

      it "returns empty stats" do
        expect(result.star_counts).to eq({})
        expect(result.my_rating_score).to be_nil
        expect(result.hot_reviews).to be_empty
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns the board of the item" do
        expect(result.board_topic).to eq(board_topic)
      end

      it "lets the user score" do
        expect(result.accepts_scores).to eq(true)
        expect(result.can_score).to eq(true)
      end

      it "counts the scores by stars" do
        expect(result.star_counts).to eq(1 => 1, 3 => 1, 4 => 1, 5 => 2)
      end

      it "returns the score of the viewer" do
        expect(result.my_rating_score).to eq(my_score)
      end

      it "returns the 3 most liked reviews" do
        expect(result.hot_reviews).to eq([first_review, second_review, third_review])
      end
    end
  end
end
