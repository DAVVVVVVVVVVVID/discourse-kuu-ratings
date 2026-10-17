import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import bodyClass from "discourse/helpers/body-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getURLWithCDN } from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";
import { isItemCategory, STARS } from "../../lib/kuu-ratings";
import HotReviews from "./hot-reviews";
import ScorePanel from "./score-panel";
import StarRating from "./star-rating";

// 评分对象页：首帖（只有那张图）隐藏，换成封面、平均分、星级分布、打分区和热评
export default class ItemHeader extends Component {
  static shouldRender({ model }, { siteSettings }) {
    return isItemCategory(model?.category_id, siteSettings);
  }

  @tracked item;

  loadItem = modifier((element, [topicId]) => {
    this.#load(topicId);
  });

  get topic() {
    return this.args.outletArgs.model;
  }

  get isLoading() {
    return this.item?.id !== this.topic.id;
  }

  get imageUrl() {
    return this.item.image_url && getURLWithCDN(this.item.image_url);
  }

  get hasScores() {
    return this.item.score_count > 0;
  }

  get scoreText() {
    return this.item.score_avg.toFixed(1);
  }

  // 5 星在上，1 星在下
  get distribution() {
    const total = this.item.score_count || 1;

    return Array.from({ length: STARS }, (_, index) => {
      const stars = STARS - index;
      const count = this.item.star_counts[stars] ?? 0;
      return {
        stars,
        count,
        barStyle: trustHTML(`width: ${(count / total) * 100}%`),
      };
    });
  }

  @action
  reload() {
    return this.#load(this.topic.id);
  }

  async #load(topicId) {
    try {
      const item = await ajax(`/kuu-ratings/items/${topicId}.json`);

      // 期间换了帖子，旧请求的结果丢掉
      if (topicId === this.topic.id) {
        this.item = item;
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{bodyClass "kuu-item-topic"}}

    <div class="kuu-item" {{this.loadItem this.topic.id}}>
      {{#if this.isLoading}}
        {{dLoadingSpinner}}
      {{else}}
        {{#if this.item.board}}
          <a class="kuu-item__board" href={{this.item.board.url}}>
            {{dIcon "angle-left"}}
            {{this.item.board.title}}
          </a>
        {{/if}}

        <section class="kuu-item__summary">
          {{#if this.imageUrl}}
            <img
              alt={{this.item.title}}
              class="kuu-item__image"
              src={{this.imageUrl}}
            />
          {{/if}}

          <div class="kuu-item__score">
            {{#if this.hasScores}}
              <span class="kuu-item__score-value">{{this.scoreText}}</span>
              <StarRating @score={{this.item.score_avg}} />
              <span class="kuu-item__score-count">
                {{i18n
                  "kuu_ratings.board.score_count"
                  count=this.item.score_count
                }}
              </span>
            {{else}}
              <span class="kuu-item__no-score">
                {{i18n "kuu_ratings.board.no_scores"}}
              </span>
            {{/if}}
          </div>

          <ul
            class="kuu-item__distribution"
            aria-label={{i18n "kuu_ratings.distribution"}}
          >
            {{#each this.distribution key="stars" as |row|}}
              <li class="kuu-item__distribution-row">
                <span class="kuu-item__distribution-label">
                  {{i18n "kuu_ratings.stars.count" count=row.stars}}
                </span>
                <span class="kuu-item__distribution-track">
                  <span
                    class="kuu-item__distribution-bar"
                    style={{row.barStyle}}
                  ></span>
                </span>
                <span class="kuu-item__distribution-count">{{row.count}}</span>
              </li>
            {{/each}}
          </ul>
        </section>

        <ScorePanel @item={{this.item}} @onChange={{this.reload}} />

        {{#if this.item.hot_reviews.length}}
          <HotReviews
            @reviews={{this.item.hot_reviews}}
            @topicUrl={{this.topic.url}}
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
