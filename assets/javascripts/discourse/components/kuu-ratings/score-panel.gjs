import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import Form from "discourse/components/form";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { COMMENT_MAX_LENGTH } from "../../lib/kuu-ratings";
import StarInput from "./star-input";
import StarRating from "./star-rating";

export const START_SCORING_EVENT = "kuu-ratings:start-scoring";

// 评分对象页的「我来打分」：没打过分时是星星和选填的短评，打过分时显示分数和删除按钮
export default class ScorePanel extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;

  @tracked flash;

  formData = { stars: null, comment: "" };
  commentValidation = `length:0,${COMMENT_MAX_LENGTH}`;

  // 页面上的「我来打分」按钮和被拦下的「回复」都滚到这里
  listenForStart = modifier((element) => {
    const start = () => {
      element.scrollIntoView({ behavior: "smooth", block: "center" });
      element.querySelector(".kuu-star-input__star")?.focus();
    };

    this.appEvents.on(START_SCORING_EVENT, start);
    return () => this.appEvents.off(START_SCORING_EVENT, start);
  });

  get myScore() {
    return this.args.item.my_rating_score;
  }

  @action
  async submit({ stars, comment }) {
    this.flash = null;

    try {
      await ajax(`/kuu-ratings/items/${this.args.item.id}/score.json`, {
        type: "POST",
        data: { stars, comment },
      });
      await this.args.onChange();
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  confirmDelete() {
    this.dialog.deleteConfirm({
      message: i18n("kuu_ratings.score.delete_confirm"),
      didConfirm: () => this.#deleteScore(),
    });
  }

  async #deleteScore() {
    try {
      await ajax(`/kuu-ratings/items/${this.args.item.id}/score.json`, {
        type: "DELETE",
      });
      await this.args.onChange();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <section
      id="kuu-score-panel"
      class="kuu-score-panel"
      {{this.listenForStart}}
    >
      <h2 class="kuu-score-panel__title">
        {{i18n "kuu_ratings.score.title"}}
      </h2>

      {{#if this.myScore}}
        <div class="kuu-score-panel__mine">
          <StarRating @score={{this.myScore.score}} />
          <span class="kuu-score-panel__mine-text">
            {{i18n "kuu_ratings.score.mine" score=this.myScore.score}}
          </span>
          <DButton
            class="btn-flat btn-danger kuu-score-panel__delete"
            @action={{this.confirmDelete}}
            @icon="trash-can"
            @label="kuu_ratings.score.delete"
          />
        </div>
      {{else if (not this.currentUser)}}
        <div class="kuu-score-panel__notice">
          <span>{{i18n "kuu_ratings.score.login_to_score"}}</span>
          <DButton
            class="btn-primary"
            @action={{routeAction "showLogin"}}
            @label="log_in"
          />
        </div>
      {{else if (not @item.accepts_scores)}}
        <p class="kuu-score-panel__notice">
          {{i18n "kuu_ratings.score.closed"}}
        </p>
      {{else if (not @item.can_score)}}
        <p class="kuu-score-panel__notice">
          {{i18n "kuu_ratings.score.cannot_score"}}
        </p>
      {{else}}
        {{#if this.flash}}
          <div class="alert alert-error kuu-score-panel__error">
            {{this.flash}}
          </div>
        {{/if}}

        <Form
          class="kuu-score-panel__form"
          @data={{this.formData}}
          @onSubmit={{this.submit}}
          as |form|
        >
          <form.Field
            @name="stars"
            @showTitle={{false}}
            @title={{i18n "kuu_ratings.score.stars"}}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <StarInput @onChange={{field.set}} @value={{field.value}} />
            </field.Control>
          </form.Field>

          <form.Field
            @format="full"
            @name="comment"
            @showTitle={{false}}
            @title={{i18n "kuu_ratings.score.comment"}}
            @type="textarea"
            @validation={{this.commentValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_ratings.score.comment_placeholder"}}
            />
          </form.Field>

          <form.Submit
            class="kuu-score-panel__submit"
            @label="kuu_ratings.score.submit"
          />
        </Form>
      {{/if}}
    </section>
  </template>
}
