# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:item_topic_id) }
    it { is_expected.to allow_values(1, 5, "3").for(:stars) }
    it { is_expected.not_to allow_values(nil, 0, 6, 4.0, 4.5, "4.5", "abc").for(:stars) }

    it "strips surrounding whitespace from the comment" do
      contract = described_class.new(comment: "  好吃  ")
      contract.validate

      expect(contract.comment).to eq("好吃")
    end

    it "treats a blank comment as a missing comment" do
      contract = described_class.new(comment: "   ")
      contract.validate

      expect(contract.comment).to be_nil
    end

    it "gives 2 points per star" do
      expect(described_class.new(stars: "4").score).to eq(8)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:board_category, :category)
    fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
    fab!(:board_topic) { Fabricate(:topic, category: board_category) }
    fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }

    let(:params) { { item_topic_id:, stars:, comment: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:item_topic_id) { item_topic.id }
    let(:stars) { 4 }
    let(:comment) { "  好吃  " }

    before do
      SiteSetting.kuu_ratings_board_category = board_category.id
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    context "when the contract is invalid" do
      let(:stars) { "4.5" }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic is not in the item category" do
      let(:item_topic_id) { board_topic.id }

      it { is_expected.to fail_to_find_a_model(:item_topic) }
    end

    context "when the item has been deleted" do
      before { item_topic.trash! }

      it { is_expected.to fail_to_find_a_model(:item_topic) }
    end

    context "when the user cannot see the item" do
      before do
        item_category.set_permissions(admins: :full)
        item_category.save!
      end

      it { is_expected.to fail_a_policy(:can_see_item) }
    end

    context "when the user is silenced" do
      fab!(:user) { Fabricate(:user, silenced_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:can_score_item) }
    end

    context "when the user is suspended" do
      fab!(:user) { Fabricate(:user, suspended_at: 1.day.ago, suspended_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:can_score_item) }
    end

    context "when the item is unlisted" do
      fab!(:item_topic) do
        Fabricate(:kuu_rating_item, category: item_category, board: board_topic, visible: false)
      end

      it { is_expected.to fail_a_policy(:can_score_item) }
    end

    # 管理员可以回复已关闭/已归档的 topic，用管理员才能证明插件自己的检查生效
    context "when an admin scores a closed item" do
      fab!(:user, :admin)
      fab!(:item_topic) do
        Fabricate(:kuu_rating_item, category: item_category, board: board_topic, closed: true)
      end

      it { is_expected.to fail_a_policy(:can_score_item) }
    end

    context "when an admin scores an archived item" do
      fab!(:user, :admin)
      fab!(:item_topic) do
        Fabricate(:kuu_rating_item, category: item_category, board: board_topic, archived: true)
      end

      it { is_expected.to fail_a_policy(:can_score_item) }
    end

    context "when the board is closed" do
      before { board_topic.update!(closed: true) }

      it { is_expected.to fail_a_policy(:board_accepts_scores) }
    end

    context "when the item has no board" do
      fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category) }

      it { is_expected.to fail_a_policy(:board_accepts_scores) }
    end

    context "when the user has already scored the item" do
      fab!(:existing_score) { Fabricate(:kuu_rating_score, item_topic:, user:) }

      it { is_expected.to fail_a_policy(:not_scored_yet) }
    end

    context "when the comment is not acceptable" do
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:comment) { "this is spam" }

      it { is_expected.to fail_a_policy(:comment_is_acceptable) }
    end

    # 短评必填（Issue #7）
    shared_examples "a rejected comment" do |error_key|
      it { is_expected.to fail_a_contract }

      it "explains what is wrong with the comment" do
        expect(result["result.contract.default"].errors.full_messages).to contain_exactly(
          error_key == :required ? I18n.t("kuu_ratings.errors.comment_required") : length_error,
        )
      end

      it "creates neither a score nor a post" do
        expect { result }.to not_change { DiscourseKuuRatings::RatingScore.count }.and not_change {
                Post.count
              }
      end
    end

    let(:length_error) { I18n.t("kuu_ratings.errors.comment_length", min: 2, max: 500) }

    context "without a comment" do
      let(:comment) { nil }

      it_behaves_like "a rejected comment", :required
    end

    context "with an empty comment" do
      let(:comment) { "" }

      it_behaves_like "a rejected comment", :required
    end

    context "with a comment made only of whitespace" do
      let(:comment) { " \n\t " }

      it_behaves_like "a rejected comment", :required
    end

    # 中文输入法常打出全角空格（U+3000），String#strip 去不掉，服务端要自己去
    context "with a comment made only of full-width spaces" do
      let(:comment) { "　　" }

      it_behaves_like "a rejected comment", :required
    end

    context "with a 1 character comment" do
      let(:comment) { " 好 " }

      it_behaves_like "a rejected comment", :length
    end

    context "with a 501 character comment" do
      let(:comment) { "好" * 501 }

      it_behaves_like "a rejected comment", :length
    end

    context "with a 2 character comment" do
      let(:comment) { "好吃" }

      it { is_expected.to run_successfully }

      it "posts the comment and links it to the score" do
        expect { result }.to change { item_topic.posts.count }.by(1)
        rating_score = result.rating_score.reload
        expect(rating_score.post_id).to eq(result.comment_post.id)
        expect(rating_score.post).to have_attributes(topic: item_topic, user:, raw: "好吃")
      end

      context "when the core minimum post length is longer" do
        before { SiteSetting.min_post_length = 8 }

        it { is_expected.to run_successfully }

        it "still posts the comment" do
          expect(result.rating_score.reload.post.raw).to eq("好吃")
        end
      end
    end

    context "with a 500 character comment" do
      let(:comment) { "好" * 500 }

      it { is_expected.to run_successfully }

      it "posts the whole comment" do
        expect(result.rating_score.reload.post.raw).to eq("好" * 500)
      end
    end

    context "when the item category requires reply approval" do
      before do
        item_category.require_reply_approval = true
        item_category.save!
      end

      it "publishes the comment without queueing it" do
        expect { result }.not_to change { ReviewableQueuedPost.count }
        expect(result.rating_score.post).to have_attributes(topic: item_topic, raw: "好吃")
      end
    end

    context "when everything's ok" do
      fab!(:other_score) { Fabricate(:kuu_rating_score, item_topic:, score: 4) }

      it { is_expected.to run_successfully }

      it "creates the score" do
        expect { result }.to change { DiscourseKuuRatings::RatingScore.count }.by(1)
        expect(result.rating_score).to have_attributes(item_topic:, user:, score: 8)
      end

      it "posts the stripped comment as a reply in the item" do
        expect { result }.to change { item_topic.posts.count }.by(1)
        expect(result.rating_score.reload.post).to have_attributes(
          topic: item_topic,
          user:,
          raw: "好吃",
          post_number: 2,
        )
      end

      it "refreshes the item stats" do
        result

        expect(item_topic.reload.custom_fields).to include(
          "kuu_score_count" => 2,
          "kuu_score_avg" => "6.0",
        )
      end
    end
  end
end
