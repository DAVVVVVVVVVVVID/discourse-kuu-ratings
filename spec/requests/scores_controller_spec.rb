# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::ScoresController do
  fab!(:user)
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

  let(:score_path) { "/kuu-ratings/items/#{item_topic.id}/score.json" }
  let(:params) { { stars: 4, comment: "好吃" } }

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
  end

  describe "when not logged in" do
    it "rejects scoring" do
      post score_path, params: params

      expect(response.status).to eq(403)
    end

    it "rejects deleting a score" do
      delete score_path

      expect(response.status).to eq(403)
    end
  end

  describe "#create" do
    before { sign_in(user) }

    it "creates the score and returns it" do
      post score_path, params: params

      expect(response.status).to eq(201)
      rating_score = DiscourseKuuRatings::RatingScore.find_by(item_topic:, user:)
      expect(response.parsed_body).to include(
        "id" => rating_score.id,
        "item_topic_id" => item_topic.id,
        "score" => 8,
        "post_id" => rating_score.post_id,
      )
      expect(rating_score.post.raw).to eq("好吃")
    end

    context "when the plugin is disabled" do
      before { SiteSetting.kuu_ratings_enabled = false }

      it "returns a 404" do
        post score_path, params: params

        expect(response.status).to eq(404)
      end
    end

    context "with an invalid number of stars" do
      let(:params) { { stars: "4.5", comment: "好吃" } }

      it "returns a 400 with the contract errors" do
        post score_path, params: params

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to contain_exactly("Stars must be an integer")
      end
    end

    context "without a comment" do
      let(:params) { { stars: 4 } }

      it "returns a 400 asking for a review and does not score the item" do
        expect { post score_path, params: params }.not_to change {
          DiscourseKuuRatings::RatingScore.count
        }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.comment_required"),
        )
      end
    end

    context "with a 1 character comment" do
      let(:params) { { stars: 4, comment: "好" } }

      it "returns a 400 with the length rule" do
        post score_path, params: params

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.comment_length", min: 2, max: 500),
        )
      end
    end

    context "when the item does not exist" do
      let(:score_path) { "/kuu-ratings/items/#{board_topic.id}/score.json" }

      it "returns a 404" do
        post score_path, params: params

        expect(response.status).to eq(404)
      end
    end

    context "when the user cannot see the item" do
      before do
        item_category.set_permissions(admins: :full)
        item_category.save!
      end

      it "returns a 404" do
        post score_path, params: params

        expect(response.status).to eq(404)
      end
    end

    context "when the item is closed" do
      before { item_topic.update!(closed: true) }

      it "returns a 403" do
        post score_path, params: params

        expect(response.status).to eq(403)
      end
    end

    context "when the board is closed" do
      before { board_topic.update!(closed: true) }

      it "returns a 422 explaining the board is closed" do
        post score_path, params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.board_closed"),
        )
      end
    end

    context "when the user has already scored the item" do
      fab!(:existing_score) { Fabricate(:kuu_rating_score, item_topic:, user:) }

      it "returns a 422 explaining the item is already scored" do
        post score_path, params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("kuu_ratings.errors.already_scored"),
        )
      end
    end

    context "when the comment contains a blocked word" do
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:params) { { stars: 4, comment: "this is spam" } }

      it "returns a 422 naming the blocked word" do
        post score_path, params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("contains_blocked_word", word: "spam"),
        )
      end
    end

    context "when the comment breaks a posting rule" do
      fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      let(:params) { { stars: 4, comment: "好吃 https://example.com/ramen 推荐" } }

      before { SiteSetting.newuser_max_links = 0 }

      it "returns a 422 with the core posting error" do
        post score_path, params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(I18n.t(:no_links_allowed))
      end
    end

    context "when the user scores too often" do
      fab!(:other_item) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

      before { RateLimiter.enable }

      after { RateLimiter.disable }

      it "returns a 429" do
        stub_const(described_class, "SCORES_PER_HOUR", 1) do
          post score_path, params: params
          expect(response.status).to eq(201)

          post "/kuu-ratings/items/#{other_item.id}/score.json", params: params
        end

        expect(response.status).to eq(429)
      end
    end
  end

  describe "#destroy" do
    before { sign_in(user) }

    context "when the user has scored the item" do
      fab!(:rating_score) { Fabricate(:kuu_rating_score, item_topic:, user:) }

      it "deletes the score" do
        expect { delete score_path }.to change {
          DiscourseKuuRatings::RatingScore.where(item_topic:, user:).count
        }.from(1).to(0)
        expect(response.status).to eq(204)
      end
    end

    context "when the user has not scored the item" do
      it "returns a 404" do
        delete score_path

        expect(response.status).to eq(404)
      end
    end
  end
end
