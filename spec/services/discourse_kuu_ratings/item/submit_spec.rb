# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::Item::Submit do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_topic_id) }
    it { is_expected.to validate_presence_of(:upload_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(30) }

    it "squishes line breaks, tabs and repeated spaces in the name" do
      contract = described_class.new(name: "天天有\n\n@someone\t [x](https://e.co)")
      contract.valid?

      expect(contract.name).to eq("天天有 @someone [x](https://e.co)")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:existing_item) do
      Fabricate(
        :kuu_rating_item,
        category: item_category,
        board: board_topic,
        title: "Ichiran ramen at Demachi",
      )
    end
    fab!(:upload) { Fabricate(:upload, user:) }

    let(:params) { { board_topic_id:, name:, upload_id: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:board_topic_id) { board_topic.id }
    let(:name) { "Ippudo" }
    let(:upload_id) { upload.id }
    let(:submission) { ReviewableKuuRatingSubmission.last }

    before do
      enable_current_plugin
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:name) { " " }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic is not in the board category" do
      let(:board_topic_id) { existing_item.id }

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

    context "when the board is closed" do
      before { board_topic.update!(closed: true) }

      it { is_expected.to fail_a_policy(:board_accepts_items) }
    end

    context "when the board is archived" do
      before { board_topic.update!(archived: true) }

      it { is_expected.to fail_a_policy(:board_accepts_items) }
    end

    context "when the user is silenced" do
      fab!(:user) { Fabricate(:user, silenced_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:submitter_is_active) }
    end

    context "when the board already has an item with the name in another case" do
      let(:name) { "ICHIRAN ramen at demachi" }

      it { is_expected.to fail_a_policy(:name_available) }
    end

    context "when the name contains a blocked word" do
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:name) { "spam ramen" }

      it { is_expected.to fail_a_policy(:no_blocked_words) }
    end

    context "when the image does not exist" do
      # 负数 id 是 core 自带的系统图片，用不存在的正数 id
      let(:upload_id) { Upload.maximum(:id) + 1 }

      it { is_expected.to fail_to_find_a_model(:uploads) }
    end

    context "when the image was uploaded by someone else" do
      fab!(:upload)

      it { is_expected.to fail_a_policy(:own_images) }
    end

    context "when the upload is not an image" do
      # 站点默认不允许上传 pdf，建好图片后再改文件名
      fab!(:upload) do
        Fabricate(:upload, user:).tap do |upload|
          upload.update_column(:original_filename, "menu.pdf")
        end
      end

      it { is_expected.to fail_a_policy(:own_images) }
    end

    context "when another board has an item with the same name" do
      fab!(:other_board) { Fabricate(:topic, category: board_category) }
      fab!(:other_board_item) do
        Fabricate(
          :kuu_rating_item,
          category: item_category,
          board: other_board,
          title: "Ippudo ramen at Shijo",
        )
      end

      let(:name) { "Ippudo ramen at Shijo" }

      it { is_expected.to run_successfully }
    end

    context "with line breaks in the name" do
      let(:name) { "天天有\n\n@someone [x](https://e.co)" }

      it "stores the squished name" do
        result

        expect(submission.payload["items"]).to eq(
          [{ "name" => "天天有 @someone [x](https://e.co)", "upload_id" => upload.id }],
        )
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "queues the item for review under its board" do
        expect { result }.to change { ReviewableKuuRatingSubmission.count }.by(1)
        expect(submission).to have_attributes(
          status: "pending",
          target_created_by: user,
          topic: board_topic,
          payload: {
            "board_topic_id" => board_topic.id,
            "items" => [{ "name" => "Ippudo", "upload_id" => upload.id }],
          },
        )
      end

      it "asks for approval" do
        result

        expect(submission.reviewable_scores.pluck(:reviewable_score_type)).to contain_exactly(
          ReviewableScore.types[:needs_approval],
        )
      end
    end
  end
end
