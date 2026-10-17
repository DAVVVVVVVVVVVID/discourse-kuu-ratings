import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { MAX_SCORE, STARS } from "../../lib/kuu-ratings";

// 只读的五颗星：10 分制，每颗星 2 分，平均分按比例点亮（可以是半颗多一点）
export default class StarRating extends Component {
  stars = Array.from({ length: STARS });

  get percent() {
    const score = Math.min(Math.max(this.args.score ?? 0, 0), MAX_SCORE);
    return (score / MAX_SCORE) * 100;
  }

  get filledStyle() {
    return trustHTML(`width: ${this.percent}%`);
  }

  get label() {
    return i18n("kuu_ratings.stars.label", {
      score: (this.args.score ?? 0).toFixed(1),
    });
  }

  <template>
    <span class="kuu-star-rating" role="img" aria-label={{this.label}}>
      <span class="kuu-star-rating__empty" aria-hidden="true">
        {{#each this.stars}}{{dIcon "star"}}{{/each}}
      </span>
      <span
        class="kuu-star-rating__filled"
        style={{this.filledStyle}}
        aria-hidden="true"
      >
        {{#each this.stars}}{{dIcon "star"}}{{/each}}
      </span>
    </span>
  </template>
}
