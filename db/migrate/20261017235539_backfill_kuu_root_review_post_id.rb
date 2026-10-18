# frozen_string_literal: true

# 楼中楼上线前，评分对象帖子里已有的回复只有 reply_to_post_number。
# 沿回复链往上找到最顶上那条短评，补上 kuu_root_review_post_id；已经有的不动，可以重复执行
class BackfillKuuRootReviewPostId < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      WITH RECURSIVE item_topics AS (
        SELECT topics.id
        FROM topics
        JOIN site_settings ON site_settings.name = 'kuu_ratings_item_category'
        WHERE site_settings.value ~ '^[0-9]+$'
          AND topics.category_id = site_settings.value::integer
      ),
      chain AS (
        SELECT posts.id AS post_id, posts.topic_id, posts.reply_to_post_number AS ancestor_number, 1 AS depth
        FROM posts
        JOIN item_topics ON item_topics.id = posts.topic_id
        WHERE posts.reply_to_post_number > 1
        UNION ALL
        SELECT chain.post_id, chain.topic_id, parent.reply_to_post_number, chain.depth + 1
        FROM chain
        JOIN posts parent
          ON parent.topic_id = chain.topic_id AND parent.post_number = chain.ancestor_number
        WHERE parent.reply_to_post_number > 1 AND chain.depth < 100
      ),
      roots AS (
        SELECT DISTINCT ON (chain.post_id) chain.post_id, root.id AS root_id
        FROM chain
        JOIN posts root
          ON root.topic_id = chain.topic_id AND root.post_number = chain.ancestor_number
        ORDER BY chain.post_id, chain.depth DESC
      )
      INSERT INTO post_custom_fields (post_id, name, value, created_at, updated_at)
      SELECT roots.post_id, 'kuu_root_review_post_id', roots.root_id::text, NOW(), NOW()
      FROM roots
      WHERE NOT EXISTS (
        SELECT 1
        FROM post_custom_fields existing
        WHERE existing.post_id = roots.post_id AND existing.name = 'kuu_root_review_post_id'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
