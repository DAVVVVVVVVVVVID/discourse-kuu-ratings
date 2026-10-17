# frozen_string_literal: true

module DiscourseKuuRatings
  class ScoresController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    SCORES_PER_HOUR = 30

    before_action :ensure_logged_in
    before_action :ensure_score_rate_limit, only: :create

    def create
      RatingScore::Create.call(service_params) do
        on_success do |rating_score:|
          render json: RatingScoreSerializer.new(rating_score, root: false).as_json,
                 status: :created
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:item_topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_item) { raise Discourse::NotFound }
        on_failed_policy(:can_score_item) { raise Discourse::InvalidAccess }
        on_failed_policy(:board_accepts_scores) do
          render_json_error(I18n.t("kuu_ratings.errors.board_closed"), status: 422)
        end
        on_failed_policy(:not_scored_yet) do
          render_json_error(I18n.t("kuu_ratings.errors.already_scored"), status: 422)
        end
        on_failed_policy(:comment_is_acceptable) do |policy|
          render_json_error(policy.reason, status: 422)
        end
        on_model_errors(:rating_score) { |model| render_json_error(model, status: 422) }
        on_model_errors(:comment_post) { |model| render_json_error(model, status: 422) }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def destroy
      RatingScore::Destroy.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:rating_score) { raise Discourse::NotFound }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    private

    def ensure_score_rate_limit
      RateLimiter.new(current_user, "kuu_ratings_score", SCORES_PER_HOUR, 1.hour).performed!
    end
  end
end
