import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { isItemCategory } from "../../lib/kuu-ratings";
import { START_SCORING_EVENT } from "./score-panel";

// 评分对象页底部用「我来打分」代替「回复」：直接回复对象的只能是短评
export default class StartScoringButton extends Component {
  static shouldRender({ topic }, { siteSettings, currentUser }) {
    return !!currentUser && isItemCategory(topic?.category_id, siteSettings);
  }

  @service appEvents;

  @action
  startScoring() {
    this.appEvents.trigger(START_SCORING_EVENT);
  }

  <template>
    <DButton
      class="btn-primary kuu-start-scoring-button"
      @action={{this.startScoring}}
      @icon="star"
      @label="kuu_ratings.score.start"
    />
  </template>
}
