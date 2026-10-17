# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::Board::Publish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:reviewable_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:moderator)
    fab!(:submitter, :user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    # 一个字的标题、和已有话题重名的对象，都不受 core 的标题规则限制
    fab!(:existing_topic) { Fabricate(:topic, title: "Ichiran ramen at Demachi") }
    fab!(:submission) do
      Fabricate(
        :kuu_board_submission,
        target_created_by: submitter,
        title: "面",
        names: ["Ichiran ramen at Demachi", "天天有 @someone [x](https://e.co)"],
      )
    end

    let(:params) { { reviewable_id: } }
    let(:dependencies) { { guardian: moderator.guardian } }
    let(:reviewable_id) { submission.id }
    let(:uploads) { Upload.where(id: submission.upload_ids).order(:id).to_a }

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
      fab!(:submission) do
        Fabricate(:kuu_board_submission, target_created_by: submitter, status: :approved)
      end

      it { is_expected.to fail_to_find_a_model(:submission) }
    end

    context "when all images have been deleted" do
      before { uploads.each(&:destroy!) }

      it { is_expected.to fail_a_policy(:uploads_still_present) }
    end

    context "when one image has been deleted" do
      before { uploads.first.destroy! }

      it { is_expected.to fail_a_policy(:uploads_still_present) }

      it "creates no topic" do
        expect { result }.not_to change { Topic.count }
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the board as the submitter, even with a one-character title" do
        expect(result.board_topic).to have_attributes(
          title: "面",
          category_id: board_category.id,
          user_id: submitter.id,
        )
        expect(result.board_topic.first_post.raw).to eq(I18n.t("kuu_ratings.board_first_post"))
      end

      it "creates every item in the board, even with a duplicate title" do
        result

        items = Topic.where(category_id: item_category.id).order(:id)
        expect(items.map(&:title)).to eq(
          ["Ichiran ramen at Demachi", "天天有 @someone [x](https://e.co)"],
        )
        expect(items.map(&:user_id)).to all(eq(submitter.id))
        expect(items.map { |item| item.custom_fields["kuu_board_topic_id"] }).to all(
          eq(result.board_topic.id),
        )
        expect(items.map { |item| item.first_post.raw }).to match(
          [include(uploads.first.short_url), include(uploads.second.short_url)],
        )
      end

      it "keeps the name inside the image alt text" do
        result

        cooked = Topic.where(category_id: item_category.id).order(:id).last.first_post.cooked
        expect(cooked).not_to include('class="mention"')
        expect(cooked).not_to include('href="https://e.co"')
      end

      it "notifies the submitter" do
        expect { result }.to change {
          Notification.where(
            user: submitter,
            notification_type: Notification.types[:post_approved],
          ).count
        }.by(1)
        expect(Notification.last.topic_id).to eq(result.board_topic.id)
      end
    end
  end
end
