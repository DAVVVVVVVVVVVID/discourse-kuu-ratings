import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { scoreForStars, STARS } from "../../lib/kuu-ratings";

// 打分用的五颗星：点第几颗就是几颗星（每颗 2 分），鼠标悬停时预览
export default class StarInput extends Component {
  @tracked hovered = null;

  stars = Array.from({ length: STARS }, (_, index) => index + 1);

  isLit = (star) => star <= this.shownStars;

  starLabel = (star) =>
    i18n("kuu_ratings.score.star_option", {
      count: star,
      score: scoreForStars(star),
    });

  get shownStars() {
    return this.hovered ?? this.args.value ?? 0;
  }

  get label() {
    return this.shownStars
      ? i18n("kuu_ratings.score.points", {
          score: scoreForStars(this.shownStars),
        })
      : i18n("kuu_ratings.score.pick");
  }

  @action
  preview(star) {
    this.hovered = star;
  }

  @action
  clearPreview() {
    this.hovered = null;
  }

  @action
  select(star) {
    this.args.onChange(star);
  }

  <template>
    <div class="kuu-star-input">
      <div
        class="kuu-star-input__stars"
        role="group"
        aria-label={{i18n "kuu_ratings.score.pick"}}
        {{on "mouseleave" this.clearPreview}}
      >
        {{#each this.stars as |star|}}
          <DButton
            class="btn-transparent kuu-star-input__star
              {{if (this.isLit star) '--lit'}}"
            aria-pressed={{if (eq star @value) "true" "false"}}
            @action={{fn this.select star}}
            @icon="star"
            @translatedAriaLabel={{this.starLabel star}}
            {{on "mouseenter" (fn this.preview star)}}
            {{on "focus" (fn this.preview star)}}
            {{on "blur" this.clearPreview}}
          />
        {{/each}}
      </div>
      <span class="kuu-star-input__label">{{this.label}}</span>
    </div>
  </template>
}
