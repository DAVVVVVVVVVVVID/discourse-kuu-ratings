# frozen_string_literal: true

module DiscourseKuuRatings
  class ItemsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      Board::ListItems.call(service_params) do
        on_success do |items:, hot_reviews:|
          render json: {
                   items:
                     ActiveModel::ArraySerializer.new(
                       items,
                       each_serializer: ItemCardSerializer,
                       scope: guardian,
                       hot_reviews:,
                     ).as_json,
                 }
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:board_topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_board) { raise Discourse::NotFound }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def show
      Item::Show.call(service_params) do
        on_success do |item_topic:, star_counts:, my_rating_score:, hot_reviews:|
          render json:
                   ItemDetailSerializer.new(
                     item_topic,
                     root: false,
                     scope: guardian,
                     star_counts:,
                     my_rating_score:,
                     hot_reviews:,
                   ).as_json
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:item_topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_item) { raise Discourse::NotFound }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
