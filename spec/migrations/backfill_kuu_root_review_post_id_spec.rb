# frozen_string_literal: true

require_relative "../../db/migrate/20261017235539_backfill_kuu_root_review_post_id"

RSpec.describe BackfillKuuRootReviewPostId do
  subject(:migrate) { described_class.new.up }

  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category) }
  fab!(:review) { Fabricate(:post, topic: item_topic) }
  fab!(:other_review) { Fabricate(:post, topic: item_topic) }

  let(:root_field) { DiscourseKuuRatings::ReviewThreads::ROOT_FIELD }

  before do
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    store_item_category(item_category.id)
  end

  after { ActiveRecord::Migration.verbose = @verbose }

  # 测试环境的站点设置不写数据库，迁移读的是 site_settings 表
  def store_item_category(value)
    SiteSetting.where(name: "kuu_ratings_item_category").delete_all
    SiteSetting.create!(
      name: "kuu_ratings_item_category",
      value:,
      data_type: SiteSetting.types[:category],
    )
  end

  # 楼中楼上线前的回复只有 reply_to_post_number，Fabricate 不触发 :post_created
  def old_reply_to(post)
    Fabricate(:post, topic: post.topic, reply_to_post_number: post.post_number)
  end

  def roots_of(*posts)
    PostCustomField
      .where(post_id: posts.map(&:id), name: root_field)
      .pluck(:post_id, :value)
      .to_h { |post_id, value| [post_id, value.to_i] }
  end

  it "assigns every reply in a chain to the review at the top" do
    reply = old_reply_to(review)
    reply_to_reply = old_reply_to(reply)
    deeper_reply = old_reply_to(reply_to_reply)
    other_reply = old_reply_to(other_review)

    migrate

    expect(roots_of(review, other_review, reply, reply_to_reply, deeper_reply, other_reply)).to eq(
      reply.id => review.id,
      reply_to_reply.id => review.id,
      deeper_reply.id => review.id,
      other_reply.id => other_review.id,
    )
  end

  it "follows the chain through deleted posts" do
    reply = old_reply_to(review)
    reply_to_reply = old_reply_to(reply)
    review.trash!
    reply.trash!

    migrate

    expect(roots_of(reply, reply_to_reply)).to eq(
      reply.id => review.id,
      reply_to_reply.id => review.id,
    )
  end

  it "leaves replies to the first post alone" do
    reply_to_item = Fabricate(:post, topic: item_topic, reply_to_post_number: 1)

    migrate

    expect(roots_of(reply_to_item)).to be_empty
  end

  it "keeps roots that are already recorded" do
    reply = old_reply_to(review)
    reply.custom_fields[root_field] = other_review.id
    reply.save_custom_fields

    migrate

    expect(roots_of(reply)).to eq(reply.id => other_review.id)
  end

  it "can run again without adding duplicates" do
    reply = old_reply_to(review)
    old_reply_to(reply)

    migrate

    expect { migrate }.not_to change { PostCustomField.where(name: root_field).count }.from(2)
  end

  it "leaves topics outside the item category alone" do
    other_post = Fabricate(:post, topic: Fabricate(:topic_with_op))
    reply = old_reply_to(other_post)

    migrate

    expect(roots_of(reply)).to be_empty
  end

  it "does nothing when the item category is not set" do
    reply = old_reply_to(review)
    SiteSetting.where(name: "kuu_ratings_item_category").delete_all

    migrate

    expect(roots_of(reply)).to be_empty
  end
end
