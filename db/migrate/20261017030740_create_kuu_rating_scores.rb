# frozen_string_literal: true
class CreateKuuRatingScores < ActiveRecord::Migration[8.1]
  def change
    create_table :kuu_rating_scores do |t|
      t.integer :item_topic_id, null: false
      t.integer :user_id, null: false
      t.integer :score, null: false
      t.integer :post_id
      t.timestamps
    end

    add_index :kuu_rating_scores, %i[item_topic_id user_id], unique: true
    add_index :kuu_rating_scores, %i[user_id created_at]
    add_index :kuu_rating_scores, :post_id, unique: true, where: "post_id IS NOT NULL"
    add_check_constraint :kuu_rating_scores,
                         "score BETWEEN 0 AND 10",
                         name: "kuu_rating_scores_score_range"
  end
end
