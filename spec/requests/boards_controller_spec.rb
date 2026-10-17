# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::BoardsController do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:first_upload) { Fabricate(:upload, user:) }
  fab!(:second_upload) { Fabricate(:upload, user:) }

  let(:params) do
    {
      title: "Ramen shops",
      items: [
        { name: "Ichiran", upload_id: first_upload.id },
        { name: "Ippudo", upload_id: second_upload.id },
      ],
    }
  end

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  describe "#create" do
    context "when not logged in" do
      it "returns a 403" do
        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "queues the board and returns the reviewable id" do
        expect { post "/kuu-ratings/boards.json", params: params }.to change {
          ReviewableKuuRatingSubmission.count
        }.by(1)

        expect(response.status).to eq(201)
        expect(response.parsed_body).to eq("reviewable_id" => ReviewableKuuRatingSubmission.last.id)
      end

      it "returns a 400 when there are too few items" do
        params[:items].pop

        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(400)
      end

      it "returns a 400 without items" do
        post "/kuu-ratings/boards.json", params: params.except(:items)

        expect(response.status).to eq(400)
      end

      it "returns a 404 when the board category is not configured" do
        SiteSetting.kuu_ratings_board_category = ""

        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(404)
      end

      it "returns a 403 when the user cannot see the board category" do
        [item_category, board_category].each do |category|
          category.set_permissions(admins: :full)
          category.save!
        end

        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(403)
      end

      it "returns a 422 when a name contains a blocked word" do
        Fabricate(:watched_word, word: "spam")
        params[:title] = "spam shops"

        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("contains_blocked_word", word: "spam"),
        )
      end

      it "returns a 422 when no image exists" do
        missing_upload_id = Upload.maximum(:id) + 1
        params[:items].each_with_index do |item, index|
          item[:upload_id] = missing_upload_id + index
        end

        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.image_invalid"),
        )
      end

      it "returns a 422 when an image belongs to someone else" do
        params[:items].last[:upload_id] = Fabricate(:upload).id

        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.image_invalid"),
        )
      end
    end

    context "when the user is silenced" do
      fab!(:user) { Fabricate(:user, silenced_till: 1.year.from_now) }

      before { sign_in(user) }

      it "returns a 403 with the reason" do
        post "/kuu-ratings/boards.json", params: params

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.cannot_submit"),
        )
      end
    end

    context "when the user submits too often" do
      before do
        RateLimiter.enable
        sign_in(user)
      end

      after { RateLimiter.disable }

      it "allows 5 boards a day" do
        6.times { post "/kuu-ratings/boards.json", params: params }

        expect(response.status).to eq(429)
        expect(ReviewableKuuRatingSubmission.count).to eq(5)
      end
    end
  end
end
