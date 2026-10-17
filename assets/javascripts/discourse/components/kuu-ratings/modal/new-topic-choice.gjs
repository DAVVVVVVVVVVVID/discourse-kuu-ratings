import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import NewBoard from "./new-board";

export default class NewTopicChoice extends Component {
  @service modal;

  @action
  createTopic() {
    this.args.closeModal();
    this.args.model.createTopic();
  }

  @action
  createBoard() {
    this.modal.show(NewBoard);
  }

  <template>
    <DModal
      class="kuu-new-topic-choice"
      @closeModal={{@closeModal}}
      @title={{i18n "kuu_ratings.new_topic_choice.title"}}
    >
      <:body>
        <div class="kuu-new-topic-choice__options">
          <DButton
            class="btn-default kuu-new-topic-choice__option --topic"
            @action={{this.createTopic}}
          >
            {{dIcon "far-comments" class="kuu-new-topic-choice__icon"}}
            <span class="kuu-new-topic-choice__text">
              <span class="kuu-new-topic-choice__label">
                {{i18n "kuu_ratings.new_topic_choice.topic"}}
              </span>
              <span class="kuu-new-topic-choice__description">
                {{i18n "kuu_ratings.new_topic_choice.topic_description"}}
              </span>
            </span>
          </DButton>

          <DButton
            class="btn-default kuu-new-topic-choice__option --board"
            @action={{this.createBoard}}
          >
            {{dIcon "star" class="kuu-new-topic-choice__icon"}}
            <span class="kuu-new-topic-choice__text">
              <span class="kuu-new-topic-choice__label">
                {{i18n "kuu_ratings.new_topic_choice.board"}}
              </span>
              <span class="kuu-new-topic-choice__description">
                {{i18n "kuu_ratings.new_topic_choice.board_description"}}
              </span>
            </span>
          </DButton>
        </div>
      </:body>
    </DModal>
  </template>
}
