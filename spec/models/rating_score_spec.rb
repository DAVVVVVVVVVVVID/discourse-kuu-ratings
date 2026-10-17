# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::RatingScore do
  fab!(:item_topic, :topic)
  fab!(:user)

  it { is_expected.to validate_presence_of(:score) }
  it { is_expected.to validate_numericality_of(:score).only_integer.is_in(0..10) }

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

  it "rejects scores outside 0–10 at the database level" do
    score = Fabricate.build(:kuu_rating_score, score: 11)

    expect { score.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "does not require a short review post" do
    expect(Fabricate.build(:kuu_rating_score, post: nil)).to be_valid
  end
end
