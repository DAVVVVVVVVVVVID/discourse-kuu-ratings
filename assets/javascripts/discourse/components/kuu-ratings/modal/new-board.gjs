import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { gt, lt } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import {
  BOARD_MAX_ITEMS,
  BOARD_MIN_ITEMS,
  emptyItem,
  NAME_MAX_LENGTH,
  normalizeName,
} from "../../../lib/kuu-ratings";
import ItemFields from "../item-fields";

const itemNumber = (index) => index + 1;

export default class NewBoard extends Component {
  @service toasts;

  @tracked flash;
  @tracked isSubmitting = false;

  formData = {
    title: "",
    items: Array.from({ length: BOARD_MIN_ITEMS }, emptyItem),
  };
  titleValidation = `required:trim|length:1,${NAME_MAX_LENGTH}`;

  #formApi;

  @action
  registerApi(api) {
    this.#formApi = api;
  }

  @action
  addItem(form) {
    form.addItemToCollection("items", emptyItem());
  }

  @action
  submitForm() {
    this.#formApi.submit();
  }

  @action
  validate(data, { addError }) {
    const seen = new Set();

    data.items.forEach((item, index) => {
      const name = normalizeName(item.name);
      if (!name) {
        return;
      }

      if (seen.has(name)) {
        addError(`items.${index}.name`, {
          title: i18n("kuu_ratings.item_form.numbered_name", {
            number: itemNumber(index),
          }),
          message: i18n("kuu_ratings.board_form.duplicate_name"),
        });
      }
      seen.add(name);
    });
  }

  @action
  async submit(data) {
    this.flash = null;
    this.isSubmitting = true;

    try {
      await ajax("/kuu-ratings/boards.json", {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({
          title: data.title,
          items: data.items.map(({ name, upload_id }) => ({ name, upload_id })),
        }),
      });

      this.args.closeModal();
      this.toasts.success({
        data: { message: i18n("kuu_ratings.submitted") },
      });
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    <DModal
      class="kuu-new-board-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{i18n "kuu_ratings.board_form.title"}}
    >
      <:body>
        <Form
          class="kuu-new-board-form"
          @data={{this.formData}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.submit}}
          @validate={{this.validate}}
          as |form data|
        >
          <form.Field
            @format="full"
            @name="title"
            @title={{i18n "kuu_ratings.board_form.name"}}
            @type="input"
            @validation={{this.titleValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_ratings.board_form.name_placeholder"}}
            />
          </form.Field>

          <div class="kuu-new-board-form__items">
            <div class="kuu-new-board-form__items-header">
              <span class="kuu-new-board-form__items-title">
                {{i18n "kuu_ratings.board_form.items"}}
              </span>
              <span class="kuu-new-board-form__items-hint">
                {{i18n
                  "kuu_ratings.board_form.items_hint"
                  min=BOARD_MIN_ITEMS
                  max=BOARD_MAX_ITEMS
                }}
              </span>
            </div>

            <form.Collection @name="items" as |collection index|>
              <ItemFields @fields={{collection}} @number={{itemNumber index}}>
                {{#if (gt data.items.length BOARD_MIN_ITEMS)}}
                  <DButton
                    class="btn-transparent kuu-new-board-form__remove"
                    @action={{fn collection.remove index}}
                    @icon="trash-can"
                    @title="kuu_ratings.board_form.remove_item"
                  />
                {{/if}}
              </ItemFields>
            </form.Collection>

            {{#if (lt data.items.length BOARD_MAX_ITEMS)}}
              <DButton
                class="btn-default kuu-new-board-form__add"
                @action={{fn this.addItem form}}
                @icon="plus"
                @label="kuu_ratings.board_form.add_item"
              />
            {{/if}}
          </div>
        </Form>
      </:body>

      <:footer>
        <DButton
          class="btn-primary kuu-new-board-modal__submit"
          @action={{this.submitForm}}
          @isLoading={{this.isSubmitting}}
          @label="kuu_ratings.board_form.submit"
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
        <span class="kuu-new-board-modal__review-hint">
          {{i18n "kuu_ratings.review_hint"}}
        </span>
      </:footer>
    </DModal>
  </template>
}
