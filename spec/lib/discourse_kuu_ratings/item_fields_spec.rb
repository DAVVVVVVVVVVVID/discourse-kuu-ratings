# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::ItemFields do
  describe ".open_board?" do
    subject(:open_board) { described_class.open_board?(board_topic_id, user.guardian) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }

    let(:board_topic_id) { board_topic.id }

    before { SiteSetting.kuu_ratings_board_category = board_category.id }

    context "when the board is open" do
      it { is_expected.to eq(true) }
    end

    context "when the board is closed" do
      before { board_topic.update!(closed: true) }

      it { is_expected.to eq(false) }
    end

    context "when the board is archived" do
      before { board_topic.update!(archived: true) }

      it { is_expected.to eq(false) }
    end

    context "when the board is unlisted" do
      before { board_topic.update!(visible: false) }

      it { is_expected.to eq(false) }
    end

    context "when the board has been deleted" do
      before { board_topic.trash! }

      it { is_expected.to eq(false) }
    end

    context "when the topic is not in the board category" do
      let(:board_topic_id) { Fabricate(:topic).id }

      it { is_expected.to eq(false) }
    end

    context "without a board id" do
      let(:board_topic_id) { nil }

      it { is_expected.to eq(false) }
    end

    context "without a board category setting" do
      before { SiteSetting.kuu_ratings_board_category = "" }

      it { is_expected.to eq(false) }
    end

    context "when the user cannot see the board" do
      before do
        board_category.set_permissions(admins: :full)
        board_category.save!
      end

      it { is_expected.to eq(false) }
    end
  end
end
