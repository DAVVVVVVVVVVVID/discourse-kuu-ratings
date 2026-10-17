# frozen_string_literal: true

RSpec.describe ReviewableKuuRatingSubmissionSerializer do
  subject(:json) { described_class.new(submission, scope: moderator.guardian, root: false).as_json }

  fab!(:moderator)
  fab!(:board_topic, :topic)

  let(:uploads) { Upload.where(id: submission.upload_ids).index_by(&:id) }

  before { enable_current_plugin }

  context "with a new board" do
    fab!(:submission) do
      Fabricate(:kuu_board_submission, title: "Ramen shops", names: %w[Ichiran Ippudo])
    end

    it "includes the board title and every item with its image" do
      expect(json[:payload]).to include("board_title" => "Ramen shops")
      expect(json[:items]).to eq(
        submission.items.map do |item|
          { name: item["name"], image_url: uploads[item["upload_id"]].url }
        end,
      )
    end
  end

  context "with an added item" do
    fab!(:submission) { Fabricate(:kuu_item_submission, board: board_topic, name: "Ippudo") }

    it "includes the board id and the item" do
      expect(json[:payload]).to include("board_topic_id" => board_topic.id)
      expect(json[:items]).to contain_exactly(
        { name: "Ippudo", image_url: uploads.values.first.url },
      )
    end
  end
end
