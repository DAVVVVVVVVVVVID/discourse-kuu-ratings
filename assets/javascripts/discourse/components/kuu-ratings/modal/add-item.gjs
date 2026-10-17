import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { emptyItem } from "../../../lib/kuu-ratings";
import ItemFields from "../item-fields";

export default class AddItem extends Component {
  @service toasts;

  @tracked flash;
  @tracked isSubmitting = false;

  formData = emptyItem();

  #formApi;

  @action
  registerApi(api) {
    this.#formApi = api;
  }

  @action
  submitForm() {
    this.#formApi.submit();
  }

  @action
  async submit({ name, upload_id }) {
    this.flash = null;
    this.isSubmitting = true;

    try {
      await ajax(`/kuu-ratings/boards/${this.args.model.board.id}/items.json`, {
        type: "POST",
        data: { name, upload_id },
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
      class="kuu-add-item-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @subtitle={{i18n "kuu_ratings.add_item.board" title=@model.board.title}}
      @title={{i18n "kuu_ratings.add_item.title"}}
    >
      <:body>
        <Form
          class="kuu-add-item-form"
          @data={{this.formData}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.submit}}
          as |form|
        >
          <ItemFields @fields={{form}} />
        </Form>
      </:body>

      <:footer>
        <DButton
          class="btn-primary kuu-add-item-modal__submit"
          @action={{this.submitForm}}
          @isLoading={{this.isSubmitting}}
          @label="kuu_ratings.add_item.submit"
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
        <span class="kuu-add-item-modal__review-hint">
          {{i18n "kuu_ratings.review_hint"}}
        </span>
      </:footer>
    </DModal>
  </template>
}
