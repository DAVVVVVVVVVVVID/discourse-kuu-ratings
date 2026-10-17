import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import ReviewableCreatedBy from "discourse/components/reviewable/created-by";
import ReviewableTopicLink from "discourse/components/reviewable/topic-link";
import { getURLWithCDN } from "discourse/lib/get-url";
import applyLightbox from "discourse/lib/lightbox";
import { i18n } from "discourse-i18n";

// 审核队列里的一条提交：新建的评分主题（带所有对象），或者往已有评分主题里添加的对象
export default class ReviewableSubmission extends Component {
  lightbox = modifier((element) => applyLightbox(element));

  get isNewBoard() {
    return !this.args.reviewable.payload?.board_topic_id;
  }

  get items() {
    return (this.args.reviewable.items ?? []).map((item) => ({
      name: item.name,
      imageUrl: item.image_url && getURLWithCDN(item.image_url),
    }));
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">
        {{i18n
          (if
            this.isNewBoard
            "kuu_ratings.reviewable.new_board"
            "kuu_ratings.reviewable.add_to_board"
          )
        }}
      </div>

      <div class="review-item__meta-topic-title">
        {{#if this.isNewBoard}}
          <span class="kuu-reviewable-submission__board-title">
            {{@reviewable.payload.board_title}}
          </span>
        {{else}}
          <ReviewableTopicLink @reviewable={{@reviewable}} />
        {{/if}}
      </div>

      <div class="review-item__meta-label">{{i18n "review.review_user"}}</div>

      <div class="review-item__meta-flagged-user">
        <ReviewableCreatedBy
          @penalties={{@reviewable.author_penalties}}
          @user={{@reviewable.target_created_by}}
        />
      </div>
    </div>

    <div class="review-item__post">
      <div class="review-item__post-content">
        <div class="kuu-reviewable-submission__items-title">
          {{i18n "kuu_ratings.reviewable.items" count=this.items.length}}
        </div>

        <ul class="kuu-reviewable-submission__items" {{this.lightbox}}>
          {{#each this.items as |item|}}
            <li class="kuu-reviewable-submission__item">
              {{#if item.imageUrl}}
                <a
                  class="lightbox kuu-reviewable-submission__image-link"
                  href={{item.imageUrl}}
                  title={{item.name}}
                >
                  <img
                    alt={{item.name}}
                    class="kuu-reviewable-submission__image"
                    loading="lazy"
                    src={{item.imageUrl}}
                  />
                </a>
              {{else}}
                <span
                  class="kuu-reviewable-submission__image --missing"
                  title={{i18n "kuu_ratings.reviewable.image_missing"}}
                ></span>
              {{/if}}
              <span class="kuu-reviewable-submission__name">{{item.name}}</span>
            </li>
          {{/each}}
        </ul>

        {{yield}}
      </div>
    </div>
  </template>
}
