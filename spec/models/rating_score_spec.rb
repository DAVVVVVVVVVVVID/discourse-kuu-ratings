# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore do
  fab!(:item_topic, :topic)
  fab!(:user)

  it { is_expected.to validate_inclusion_of(:score).in_array([2, 4, 6, 8, 10]) }

  it "allows one score per user per item" do
    Fabricate(:kuu_rating_score, item_topic:, user:)

    duplicate = Fabricate.build(:kuu_rating_score, item_topic:, user:)
    expect(duplicate).not_to be_valid

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same user to score different items" do
    Fabricate(:kuu_rating_score, item_topic:, user:)

    expect(Fabricate.build(:kuu_rating_score, user:)).to be_valid
  end

  it "rejects scores that are not whole stars at the database level" do
    score = Fabricate.build(:kuu_rating_score, score: 7)

    expect { score.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "does not require a short review post" do
    expect(Fabricate.build(:kuu_rating_score, post: nil)).to be_valid
  end

  it "still finds its item after the item topic is deleted" do
    rating_score = Fabricate(:kuu_rating_score, item_topic:)
    item_topic.trash!

    expect(rating_score.reload.item_topic).to eq(item_topic)
  end

  describe ".score_for_stars" do
    it "gives 2 points per star" do
      expect(described_class.score_for_stars(4)).to eq(8)
    end
  end

  describe ".refresh_item_stats" do
    it "stores the count and the average on the item topic" do
      Fabricate(:kuu_rating_score, item_topic:, score: 10)
      Fabricate(:kuu_rating_score, item_topic:, score: 6)
      Fabricate(:kuu_rating_score, item_topic:, score: 8)

      described_class.refresh_item_stats(item_topic)

      item_topic.reload
      expect(item_topic.custom_fields["kuu_score_count"]).to eq(3)
      expect(item_topic.custom_fields["kuu_score_avg"]).to eq("8.0")
    end

    it "rounds the average to two decimals" do
      [10, 8, 8].each { |score| Fabricate(:kuu_rating_score, item_topic:, score:) }

      described_class.refresh_item_stats(item_topic)

      expect(item_topic.reload.custom_fields["kuu_score_avg"]).to eq("8.67")
    end

    it "clears the average when the last score is removed" do
      Fabricate(:kuu_rating_score, item_topic:)
      described_class.refresh_item_stats(item_topic)

      described_class.where(item_topic:).delete_all
      described_class.refresh_item_stats(item_topic)

      item_topic.reload
      expect(item_topic.custom_fields["kuu_score_count"]).to eq(0)
      expect(item_topic.custom_fields).not_to have_key("kuu_score_avg")
    end
  end
end
