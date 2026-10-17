# frozen_string_literal: true

RSpec.describe ReviewableKuuRatingSubmission do
  fab!(:moderator)
  fab!(:submitter, :user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:board_submission) do
    Fabricate(:kuu_board_submission, target_created_by: submitter, title: "Ramen shops")
  end
  fab!(:item_submission) do
    Fabricate(
      :kuu_item_submission,
      target_created_by: submitter,
      board: board_topic,
      name: "Ippudo",
    )
  end

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  def referenced_upload_ids(submission)
    UploadReference.where(target_type: described_class.name, target_id: submission.id).pluck(
      :upload_id,
    )
  end

  def action_ids(submission)
    submission.actions_for(moderator.guardian).to_a.map(&:server_action)
  end

  describe "upload references" do
    it "references the images while the submission is pending" do
      expect(referenced_upload_ids(board_submission)).to match_array(board_submission.upload_ids)
    end

    it "releases the images once approved" do
      board_submission.perform(moderator, :approve_kuu_rating_submission)

      expect(referenced_upload_ids(board_submission)).to be_empty
    end

    it "releases the images once rejected" do
      board_submission.perform(moderator, :reject_kuu_rating_submission)

      expect(referenced_upload_ids(board_submission)).to be_empty
    end

    it "releases the images once ignored" do
      board_submission.transition_to(:ignored, moderator)

      expect(referenced_upload_ids(board_submission)).to be_empty
    end
  end

  describe "#actions_for" do
    it "offers approving and rejecting" do
      expect(action_ids(board_submission)).to contain_exactly(
        "approve_kuu_rating_submission",
        "reject_kuu_rating_submission",
      )
    end

    it "offers only rejecting once the submitter is gone" do
      board_submission.update_columns(target_created_by_id: nil)

      expect(action_ids(board_submission.reload)).to contain_exactly("reject_kuu_rating_submission")
    end
  end

  describe "approving" do
    it "publishes a new board and points to it" do
      result = board_submission.perform(moderator, :approve_kuu_rating_submission)

      expect(result.success?).to eq(true)
      board_submission.reload
      expect(board_submission).to be_approved
      expect(board_submission.target).to have_attributes(
        title: "Ramen shops",
        category_id: board_category.id,
      )
    end

    it "publishes an added item and points to it" do
      result = item_submission.perform(moderator, :approve_kuu_rating_submission)

      expect(result.success?).to eq(true)
      item_submission.reload
      expect(item_submission).to be_approved
      expect(item_submission.target).to have_attributes(
        title: "Ippudo",
        category_id: item_category.id,
      )
    end

    it "fails with an explanation when the board has been closed" do
      board_topic.update!(closed: true)

      result = item_submission.perform(moderator, :approve_kuu_rating_submission)

      expect(result.success?).to eq(false)
      expect(result.errors.full_messages).to contain_exactly(
        I18n.t("kuu_ratings.errors.board_closed"),
      )
      expect(item_submission.reload).to be_pending
    end

    it "fails with an explanation when the name has been taken" do
      Fabricate(:kuu_rating_item, category: item_category, board: board_topic).update_column(
        :title,
        "IPPUDO",
      )

      result = item_submission.perform(moderator, :approve_kuu_rating_submission)

      expect(result.errors.full_messages).to contain_exactly(
        I18n.t("kuu_ratings.errors.name_taken"),
      )
    end

    it "fails with an explanation and creates nothing when an image has been deleted" do
      Upload.find(board_submission.upload_ids.first).destroy!

      result = nil
      expect {
        result = board_submission.perform(moderator, :approve_kuu_rating_submission)
      }.not_to change { Topic.count }

      expect(result.errors.full_messages).to contain_exactly(
        I18n.t("kuu_ratings.errors.image_missing"),
      )
      expect(board_submission.reload).to be_pending
    end

    it "explains a deleted image of an added item" do
      Upload.find(item_submission.upload_ids.first).destroy!

      result = item_submission.perform(moderator, :approve_kuu_rating_submission)

      expect(result.errors.full_messages).to contain_exactly(
        I18n.t("kuu_ratings.errors.image_missing"),
      )
    end
  end

  describe "rejecting" do
    it "tells the submitter that the board was not approved" do
      expect { board_submission.perform(moderator, :reject_kuu_rating_submission) }.to change {
        Topic.private_messages_for_user(submitter).count
      }.by(1)

      message = Topic.private_messages_for_user(submitter).last
      expect(message.title).to eq(
        I18n.t("system_messages.kuu_rating_submission_rejected.subject_template"),
      )
      expect(message.first_post.raw).to include("Ramen shops")
      expect(board_submission.reload).to be_rejected
    end

    it "names the item in the message for an added item" do
      item_submission.perform(moderator, :reject_kuu_rating_submission)

      expect(Topic.private_messages_for_user(submitter).last.first_post.raw).to include("Ippudo")
    end

    it "sends no message once the submitter is gone" do
      board_submission.update_columns(target_created_by_id: nil)

      expect {
        board_submission.reload.perform(moderator, :reject_kuu_rating_submission)
      }.not_to change { Topic.private_messages.count }
      expect(board_submission.reload).to be_rejected
    end
  end

  describe "deleting the submitter" do
    it "ignores the submission and releases its images" do
      UserDestroyer.new(moderator).destroy(submitter)

      expect(board_submission.reload).to be_ignored
      expect(referenced_upload_ids(board_submission)).to be_empty
    end
  end
end
