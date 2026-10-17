# frozen_string_literal: true

RSpec.describe "Creating rating items" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }

  let(:raw) { "Rich broth and thick noodles.\n\n![ramen](https://example.com/ramen.png)" }
  let(:topic_custom_fields) do
    { kuu_board_topic_id: board_topic.id, kuu_tagline: "Tonkotsu ramen" }
  end
  let(:params) do
    {
      title: "Ramen shop near Hyakumanben",
      raw: raw,
      category: item_category.id,
      topic_custom_fields: topic_custom_fields,
    }
  end

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    sign_in(user)
  end

  def expect_item_fields(topic)
    topic.reload
    expect(topic.custom_fields["kuu_board_topic_id"]).to eq(board_topic.id)
    expect(topic.custom_fields["kuu_tagline"]).to eq("Tonkotsu ramen")
  end

  def expect_rejected_with(message)
    expect { post "/posts.json", params: params }.not_to change { ReviewableQueuedPost.count }
    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(message)
  end

  context "when the item category does not require approval" do
    it "saves the custom fields" do
      post "/posts.json", params: params

      expect(response.status).to eq(200)
      expect_item_fields(Topic.find(response.parsed_body["topic_id"]))
    end
  end

  context "when the item category requires topic approval" do
    before do
      item_category.require_topic_approval = true
      item_category.save!
    end

    it "keeps the custom fields after the item is approved" do
      post "/posts.json", params: params
      expect(response.parsed_body["action"]).to eq("enqueued")

      reviewable = ReviewableQueuedPost.last
      expect(reviewable.perform(admin, :approve_post).success?).to eq(true)

      expect_item_fields(reviewable.reload.target.topic)
    end

    it "rejects an invalid item before it reaches the queue" do
      topic_custom_fields[:kuu_tagline] = ""
      expect_rejected_with(I18n.t("kuu_ratings.errors.tagline_required"))
    end
  end

  describe "validation" do
    it "requires a tagline" do
      topic_custom_fields.delete(:kuu_tagline)
      expect_rejected_with(I18n.t("kuu_ratings.errors.tagline_required"))
    end

    it "limits the tagline length" do
      topic_custom_fields[:kuu_tagline] = "a" * 41
      expect_rejected_with(I18n.t("kuu_ratings.errors.tagline_too_long", count: 40))
    end

    it "requires an image in the post" do
      params[:raw] = "No picture here, only words about the ramen shop."
      expect_rejected_with(I18n.t("kuu_ratings.errors.image_required"))
    end

    it "does not count an emoji as an image" do
      params[:raw] = "Delicious ramen, highly recommended :smile:"
      expect_rejected_with(I18n.t("kuu_ratings.errors.image_required"))
    end

    it "requires a board" do
      topic_custom_fields.delete(:kuu_board_topic_id)
      expect_rejected_with(I18n.t("kuu_ratings.errors.board_invalid"))
    end

    it "requires the board to be in the board category" do
      topic_custom_fields[:kuu_board_topic_id] = Fabricate(:topic).id
      expect_rejected_with(I18n.t("kuu_ratings.errors.board_invalid"))
    end

    it "requires the board to be open" do
      board_topic.update!(closed: true)
      expect_rejected_with(I18n.t("kuu_ratings.errors.board_invalid"))
    end

    it "requires the board to be visible to the user" do
      board_topic.update!(visible: false)
      expect_rejected_with(I18n.t("kuu_ratings.errors.board_invalid"))
    end

    it "does not validate topics in other categories" do
      post "/posts.json",
           params: {
             title: "An ordinary topic in another category",
             raw: "Nothing to do with ratings at all here.",
             category: Fabricate(:category).id,
           }

      expect(response.status).to eq(200)
    end

    it "does not validate when the plugin is disabled" do
      SiteSetting.kuu_ratings_enabled = false

      post "/posts.json", params: params.except(:topic_custom_fields)

      expect(response.status).to eq(200)
    end
  end
end
