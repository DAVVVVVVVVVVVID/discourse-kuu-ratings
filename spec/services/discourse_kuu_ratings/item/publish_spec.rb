# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::Item::Publish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:reviewable_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:moderator)
    fab!(:submitter, :user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:submission) do
      Fabricate(:kuu_item_submission, target_created_by: submitter, board: board_topic, name: "面")
    end

    let(:params) { { reviewable_id: } }
    let(:dependencies) { { guardian: moderator.guardian } }
    let(:reviewable_id) { submission.id }
    let(:upload) { Upload.find(submission.upload_ids.first) }

    before do
      enable_current_plugin
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:reviewable_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the submission has already been handled" do
      fab!(:submission) { Fabricate(:kuu_item_submission, board: board_topic, status: :rejected) }

      it { is_expected.to fail_to_find_a_model(:submission) }
    end

    context "when the board has been deleted" do
      before { board_topic.trash! }

      it { is_expected.to fail_to_find_a_model(:board_topic) }
    end

    context "when the board has been closed" do
      before { board_topic.update!(closed: true) }

      it { is_expected.to fail_a_policy(:board_accepts_items) }
    end

    context "when an item with the same name was published in the meantime" do
      fab!(:rival_item) do
        Fabricate(
          :kuu_rating_item,
          category: item_category,
          board: board_topic,
          title: "Rival ramen shop at Shijo",
        )
      end

      # 话题标题至少 15 字，fabricate 时用长标题，再改成和提交一样的名称
      before { rival_item.update_column(:title, "面") }

      it { is_expected.to fail_a_policy(:name_still_available) }
    end

    context "when the image has been deleted" do
      before { upload.destroy! }

      it { is_expected.to fail_a_policy(:uploads_still_present) }
    end

    context "when another topic has the same title" do
      fab!(:existing_topic) { Fabricate(:topic, title: "Ichiran ramen at Demachi") }
      fab!(:submission) do
        Fabricate(
          :kuu_item_submission,
          target_created_by: submitter,
          board: board_topic,
          name: "Ichiran ramen at Demachi",
        )
      end

      it { is_expected.to run_successfully }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the item in the board as the submitter, even with a one-character title" do
        expect(result.item_topic).to have_attributes(
          title: "面",
          category_id: item_category.id,
          user_id: submitter.id,
        )
        expect(result.item_topic.custom_fields["kuu_board_topic_id"]).to eq(board_topic.id)
        expect(result.item_topic.first_post.raw).to include(upload.short_url)
      end

      it "notifies the submitter" do
        expect { result }.to change {
          Notification.where(
            user: submitter,
            notification_type: Notification.types[:post_approved],
          ).count
        }.by(1)
        expect(Notification.last.topic_id).to eq(result.item_topic.id)
      end
    end
  end
end
