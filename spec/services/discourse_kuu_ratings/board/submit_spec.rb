# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::Board::Submit do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(title: "Ramen shops", items: build_items(2)) }

    def build_items(count)
      Array.new(count) { |index| { name: "Item #{index}", upload_id: index + 1 } }
    end

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(30) }
    it { is_expected.to allow_values(build_items(2), build_items(20)).for(:items) }
    it { is_expected.not_to allow_values(build_items(1), build_items(21)).for(:items) }

    it "requires a name and an image for each item" do
      contract =
        described_class.new(
          title: "Ramen shops",
          items: [{ name: " ", upload_id: nil }, { name: "Ippudo", upload_id: 2 }],
        )
      contract.valid?

      expect(contract.errors.attribute_names).to contain_exactly(
        :"items[0].name",
        :"items[0].upload_id",
      )
    end

    it "limits each item name to 30 characters" do
      contract =
        described_class.new(
          title: "Ramen shops",
          items: [{ name: "a" * 31, upload_id: 1 }, { name: "b" * 30, upload_id: 2 }],
        )
      contract.valid?

      expect(contract.errors.attribute_names).to contain_exactly(:"items[0].name")
    end

    it "rejects item names that differ only in case" do
      contract =
        described_class.new(
          title: "Ramen shops",
          items: [{ name: "Ichiran", upload_id: 1 }, { name: "ICHIRAN", upload_id: 2 }],
        )
      contract.valid?

      expect(contract.errors[:items]).to contain_exactly(
        I18n.t("kuu_ratings.errors.duplicate_names"),
      )
    end

    it "rejects item names that differ only in whitespace" do
      contract =
        described_class.new(
          title: "Ramen shops",
          items: [{ name: "Ichiran", upload_id: 1 }, { name: " Ichiran ", upload_id: 2 }],
        )
      contract.valid?

      expect(contract.errors[:items]).to contain_exactly(
        I18n.t("kuu_ratings.errors.duplicate_names"),
      )
    end

    it "rejects a missing item list" do
      contract = described_class.new(title: "Ramen shops")

      expect { contract.valid? }.not_to raise_error
      expect(contract.errors.attribute_names).to include(:items)
    end

    it "squishes line breaks, tabs and repeated spaces in names" do
      contract =
        described_class.new(
          title: "天天有\n\n@someone [x](https://e.co)",
          items: [{ name: "Ichi\t\tran\n ramen", upload_id: 1 }, { name: "Ippudo", upload_id: 2 }],
        )
      contract.valid?

      expect(contract.title).to eq("天天有 @someone [x](https://e.co)")
      expect(contract.items.map(&:name)).to eq(["Ichi ran ramen", "Ippudo"])
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:first_upload) { Fabricate(:upload, user:) }
    fab!(:second_upload) { Fabricate(:upload, user:) }

    let(:params) { { title:, items: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:title) { "Ramen shops" }
    let(:items) do
      [
        { name: "Ichiran", upload_id: first_upload.id },
        { name: "Ippudo", upload_id: second_upload.id },
      ]
    end
    let(:submission) { ReviewableKuuRatingSubmission.last }
    let(:missing_upload_id) { Upload.maximum(:id) + 1 }

    before do
      enable_current_plugin
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:items) { [{ name: "Ichiran", upload_id: first_upload.id }] }

      it { is_expected.to fail_a_contract }
    end

    context "when the board category is not configured" do
      before { SiteSetting.kuu_ratings_board_category = "" }

      it { is_expected.to fail_to_find_a_model(:board_category) }
    end

    context "when the user cannot see the board category" do
      before do
        # 子分类的权限不能比父分类宽，要先收紧子分类
        [item_category, board_category].each do |category|
          category.set_permissions(admins: :full)
          category.save!
        end
      end

      it { is_expected.to fail_a_policy(:can_see_board_category) }
    end

    context "when the user is silenced" do
      fab!(:user) { Fabricate(:user, silenced_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:submitter_is_active) }
    end

    context "when the user is suspended" do
      fab!(:user) { Fabricate(:user, suspended_at: 1.day.ago, suspended_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:submitter_is_active) }
    end

    context "when an item name contains a blocked word" do
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:items) do
        [
          { name: "Ichiran", upload_id: first_upload.id },
          { name: "spam ramen", upload_id: second_upload.id },
        ]
      end

      it { is_expected.to fail_a_policy(:no_blocked_words) }
    end

    context "when no image exists" do
      # 负数 id 是 core 自带的系统图片，用不存在的正数 id
      let(:items) do
        [
          { name: "Ichiran", upload_id: missing_upload_id },
          { name: "Ippudo", upload_id: missing_upload_id + 1 },
        ]
      end

      it { is_expected.to fail_to_find_a_model(:uploads) }
    end

    context "when one image does not exist" do
      let(:items) do
        [
          { name: "Ichiran", upload_id: first_upload.id },
          { name: "Ippudo", upload_id: missing_upload_id },
        ]
      end

      it { is_expected.to fail_a_policy(:own_images) }
    end

    context "when an image was uploaded by someone else" do
      fab!(:second_upload, :upload)

      it { is_expected.to fail_a_policy(:own_images) }
    end

    context "when an upload is not an image" do
      # 站点默认不允许上传 pdf，建好图片后再改文件名
      fab!(:second_upload) do
        Fabricate(:upload, user:).tap do |upload|
          upload.update_column(:original_filename, "menu.pdf")
        end
      end

      it { is_expected.to fail_a_policy(:own_images) }
    end

    context "with line breaks in the names" do
      let(:title) { "天天有\n\n@someone [x](https://e.co)" }
      let(:items) do
        [
          { name: "Ichi\nran", upload_id: first_upload.id },
          { name: "Ippudo", upload_id: second_upload.id },
        ]
      end

      it "stores the squished names" do
        result

        expect(submission.payload).to include(
          "board_title" => "天天有 @someone [x](https://e.co)",
          "items" => [
            { "name" => "Ichi ran", "upload_id" => first_upload.id },
            { "name" => "Ippudo", "upload_id" => second_upload.id },
          ],
        )
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "queues the board with its items for review" do
        expect { result }.to change { ReviewableKuuRatingSubmission.count }.by(1)
        expect(submission).to have_attributes(
          status: "pending",
          target_created_by: user,
          topic: nil,
          reviewable_by_moderator: true,
          payload: {
            "board_title" => "Ramen shops",
            "items" => [
              { "name" => "Ichiran", "upload_id" => first_upload.id },
              { "name" => "Ippudo", "upload_id" => second_upload.id },
            ],
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
