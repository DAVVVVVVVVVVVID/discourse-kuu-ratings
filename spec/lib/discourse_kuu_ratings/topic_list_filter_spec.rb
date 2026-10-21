# frozen_string_literal: true

RSpec.describe DiscourseKuuRatings::TopicListFilter do
  fab!(:user) { Fabricate(:user, created_at: 1.year.ago) }
  fab!(:board_category, :category)
  fab!(:item_category) { Fabricate(:category, parent_category: board_category) }
  fab!(:board_topic) { Fabricate(:topic, category: board_category) }
  fab!(:item_topic) { Fabricate(:kuu_rating_item, category: item_category, board: board_topic) }
  fab!(:other_topic, :topic_with_op)

  before do
    enable_current_plugin
    SiteSetting.kuu_ratings_board_category = board_category.id
    SiteSetting.kuu_ratings_item_category = item_category.id
    user.user_option.update!(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)
  end

  def topic_ids(list)
    list.topics.map(&:id)
  end

  def query(**options)
    TopicQuery.new(user, options)
  end

  def track_with_unread_reply(topic)
    Fabricate(:post, topic:)
    TopicUser.change(
      user.id,
      topic.id,
      notification_level: TopicUser.notification_levels[:tracking],
    )
    TopicUser.update_last_read(user, topic.id, 1, 1, 1)
  end

  it "hides items from the latest list" do
    expect(topic_ids(query.list_latest)).to include(board_topic.id, other_topic.id)
    expect(topic_ids(query.list_latest)).not_to include(item_topic.id)
  end

  it "hides items from the new list" do
    expect(topic_ids(query.list_new)).to include(other_topic.id)
    expect(topic_ids(query.list_new)).not_to include(item_topic.id)
  end

  it "hides items from the unread list" do
    user.user_stat.update!(first_unread_at: 1.day.ago)
    [item_topic, other_topic].each { |topic| track_with_unread_reply(topic) }

    expect(topic_ids(query.list_unread)).to contain_exactly(other_topic.id)
  end

  it "hides items from the top list" do
    [item_topic, other_topic].each { |topic| TopTopic.create!(topic:, all_score: 1) }

    expect(topic_ids(query.list_top_for(:all))).to contain_exactly(other_topic.id)
  end

  it "hides items from the board category page" do
    expect(topic_ids(query(category: board_category.id).list_latest)).not_to include(item_topic.id)
  end

  it "hides items from the suggested topics" do
    suggested = query.list_suggested_for(other_topic)

    expect(topic_ids(suggested)).to include(board_topic.id)
    expect(topic_ids(suggested)).not_to include(item_topic.id)
  end

  it "hides items from the item category page" do
    expect(topic_ids(query(category: item_category.id).list_latest)).not_to include(item_topic.id)
    expect(topic_ids(query(category: item_category.id.to_s).list_latest)).not_to include(
      item_topic.id,
    )
  end

  context "when the item category is a top-level category" do
    before do
      item_category.update!(parent_category: nil)
      SiteSetting.kuu_ratings_item_category = item_category.id
    end

    it "hides items when the category is given by slug" do
      expect(topic_ids(query(category: item_category.slug).list_latest)).not_to include(
        item_topic.id,
      )
    end
  end

  it "hides items when a subcategory slug is given" do
    expect(topic_ids(query(category: item_category.slug).list_latest)).not_to include(item_topic.id)
  end

  it "hides items from the topics a user created" do
    other_topic.update!(user: item_topic.user)

    expect(topic_ids(query.list_topics_by(item_topic.user))).to contain_exactly(other_topic.id)
  end

  context "when the item category is not set" do
    before { SiteSetting.kuu_ratings_item_category = "" }

    it "lists items everywhere" do
      expect(topic_ids(query.list_latest)).to include(item_topic.id)
    end
  end

  context "when the plugin is disabled" do
    before { SiteSetting.kuu_ratings_enabled = false }

    it "lists items everywhere" do
      expect(topic_ids(query.list_latest)).to include(item_topic.id)
      expect(topic_ids(query(category: board_category.id).list_latest)).to include(item_topic.id)
      expect(topic_ids(query(category: item_category.id).list_latest)).to include(item_topic.id)
      expect(topic_ids(query.list_topics_by(item_topic.user))).to include(item_topic.id)
    end
  end
end
