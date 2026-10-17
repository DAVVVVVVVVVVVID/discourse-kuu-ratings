# frozen_string_literal: true

module DiscourseKuuRatings
  class BoardsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    SUBMISSIONS_PER_DAY = 5

    before_action :ensure_logged_in
    before_action :ensure_submission_rate_limit

    def create
      Board::Submit.call(service_params) do
        on_success do |submission:|
          render json: { reviewable_id: submission.id }, status: :created
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:board_category) { raise Discourse::NotFound }
        on_failed_policy(:can_see_board_category) { raise Discourse::InvalidAccess }
        on_failed_policy(:submitter_is_active) do |policy|
          render_json_error(policy.reason, status: 403)
        end
        on_failed_policy(:no_blocked_words) { |policy| render_json_error(policy.reason, status: 422) }
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
        "kuu_ratings_board_submission",
        SUBMISSIONS_PER_DAY,
        1.day,
      ).performed!
    end
  end
end
