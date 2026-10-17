import Component from "@glimmer/component";
import { getURLWithCDN } from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import StarRating from "./star-rating";

// 评分主题页的一个评分对象：左图片，中间名称和第一条热评，右边星星、平均分和打分人数
export default class BoardItemRow extends Component {
  get imageUrl() {
    return this.args.item.image_url && getURLWithCDN(this.args.item.image_url);
  }

  get hasScores() {
    return this.args.item.score_count > 0;
  }

  get scoreText() {
    return this.args.item.score_avg.toFixed(1);
  }

  // 热评只显示一行纯文本；DOMParser 不执行脚本，结果用 {{}} 输出
  get hotReviewText() {
    const cooked = this.args.item.hot_review?.cooked;
    if (!cooked) {
      return;
    }

    const doc = new DOMParser().parseFromString(cooked, "text/html");
    return doc.body.textContent.replace(/\s+/g, " ").trim();
  }

  <template>
    <li class="kuu-board-item">
      <a class="kuu-board-item__link" href={{@item.url}}>
        {{#if this.imageUrl}}
          <img
            alt=""
            class="kuu-board-item__image"
            loading="lazy"
            src={{this.imageUrl}}
          />
        {{else}}
          <span class="kuu-board-item__image --placeholder"></span>
        {{/if}}

        <span class="kuu-board-item__main">
          <span class="kuu-board-item__name">{{@item.title}}</span>
          {{#if this.hotReviewText}}
            <span class="kuu-board-item__review">
              <span class="kuu-board-item__review-user">
                {{@item.hot_review.user.username}}
              </span>
              <span
                class="kuu-board-item__review-text"
              >{{this.hotReviewText}}</span>
            </span>
          {{/if}}
        </span>

        <span class="kuu-board-item__score">
          {{#if this.hasScores}}
            <StarRating @score={{@item.score_avg}} />
            <span class="kuu-board-item__score-value">{{this.scoreText}}</span>
            <span class="kuu-board-item__score-count">
              {{i18n "kuu_ratings.board.score_count" count=@item.score_count}}
            </span>
          {{else}}
            <span class="kuu-board-item__no-score">
              {{i18n "kuu_ratings.board.no_scores"}}
            </span>
          {{/if}}
        </span>
      </a>
    </li>
  </template>
}
