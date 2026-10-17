# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore::Policy::CommentIsAcceptable do
  subject(:policy) { described_class.new(context) }

  fab!(:user)
  fab!(:item_topic, :topic_with_op)

  let(:context) { Service::Base::Context.build(params:, item_topic:, guardian: user.guardian) }
  let(:params) { DiscourseKuuRatings::RatingScore::Create::Contract.new(comment:) }
  let(:comment) { "好吃" }

  describe "#call" do
    subject(:result) { policy.call }

    context "with a short comment" do
      it "accepts it even though it is shorter than the minimum post length" do
        expect(result).to eq(true)
      end
    end

    context "when the comment contains a blocked word" do
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:comment) { "this is spam" }

      it "rejects it" do
        expect(result).to eq(false)
      end
    end

    context "when the comment breaks a posting rule" do
      fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      let(:comment) { "好吃 https://example.com/ramen 推荐" }

      before { SiteSetting.newuser_max_links = 0 }

      it "rejects it" do
        expect(result).to eq(false)
      end
    end
  end

  describe "#reason" do
    subject(:reason) { policy.reason }

    context "when the comment contains one blocked word" do
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:comment) { "this is spam" }

      it "names the blocked word" do
        expect(reason).to eq(I18n.t("contains_blocked_word", word: "spam"))
      end
    end

    context "when the comment contains several blocked words" do
      fab!(:spam_word) { Fabricate(:watched_word, word: "spam") }
      fab!(:scam_word) { Fabricate(:watched_word, word: "scam") }

      let(:comment) { "spam and scam" }

      # 词的顺序由 core 的 WordWatcher 决定
      it "lists all blocked words" do
        expect(reason).to be_in(
          %w[spam scam].permutation.map do |words|
            I18n.t("contains_blocked_words", words: words.join(", "))
          end,
        )
      end
    end

    context "when the comment breaks a posting rule" do
      fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      let(:comment) { "好吃 https://example.com/ramen 推荐" }

      before { SiteSetting.newuser_max_links = 0 }

      it "returns the core posting error" do
        expect(reason).to eq(I18n.t(:no_links_allowed))
      end
    end

    context "when the comment contains a blocked word and breaks a posting rule" do
      fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
      fab!(:watched_word) { Fabricate(:watched_word, word: "spam") }

      let(:comment) { "spam https://example.com/ramen" }

      before { SiteSetting.newuser_max_links = 0 }

      it "reports only the blocked word" do
        expect(reason).to eq(I18n.t("contains_blocked_word", word: "spam"))
      end
    end
  end
end
