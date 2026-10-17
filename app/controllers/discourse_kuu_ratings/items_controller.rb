# frozen_string_literal: true

module DiscourseKuuRatings
  class ItemsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    SUBMISSIONS_PER_DAY = 20

    before_action :ensure_logged_in, only: :create
    before_action :ensure_submission_rate_limit, only: :create

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
        on_success do |item_topic:, board_topic:, accepts_scores:, can_score:, star_counts:, my_rating_score:, hot_reviews:|
          render json:
                   ItemDetailSerializer.new(
                     item_topic,
                     root: false,
                     scope: guardian,
                     board_topic:,
                     accepts_scores:,
                     can_score:,
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

    def create
      Item::Submit.call(service_params) do
        on_success { |submission:| render json: { reviewable_id: submission.id }, status: :created }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:board_topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_board) { raise Discourse::NotFound }
        on_failed_policy(:board_accepts_items) do
          render_json_error(I18n.t("kuu_ratings.errors.board_closed"), status: 422)
        end
        on_failed_policy(:submitter_is_active) do |policy|
          render_json_error(policy.reason, status: 403)
        end
        on_failed_policy(:name_available) do
          render_json_error(I18n.t("kuu_ratings.errors.name_taken"), status: 422)
        end
        on_failed_policy(:no_blocked_words) do |policy|
          render_json_error(policy.reason, status: 422)
        end
        on_model_not_found(:uploads) do
          render_json_error(I18n.t("kuu_ratings.errors.image_invalid"), status: 422)
        end
        on_failed_policy(:own_images) { |policy| render_json_error(policy.reason, status: 422) }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    private

    def ensure_submission_rate_limit
      RateLimiter.new(
        current_user,
        "kuu_ratings_item_submission",
        SUBMISSIONS_PER_DAY,
        1.day,
      ).performed!
    end
  end
end
