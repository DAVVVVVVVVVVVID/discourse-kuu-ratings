# frozen_string_literal: true

module DiscourseKuuRatings
  class ReviewsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def replies
      Review::ListReplies.call(service_params) do
        on_success do |review:, replies:, thread_batch:|
          render json:
                   thread_batch.thread_json(review.id).merge(
                     has_more: replies.size > ReviewThreads::PAGE_SIZE,
                   )
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:review) { raise Discourse::NotFound }
        on_failed_policy(:can_see_review) { raise Discourse::NotFound }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
