import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import AddItem from "./modal/add-item";

export default class AddItemButton extends Component {
  @service modal;

  @action
  addItem() {
    this.modal.show(AddItem, { model: { board: this.args.board } });
  }

  <template>
    <DButton
      class="btn-primary kuu-add-item-button"
      @action={{this.addItem}}
      @icon="plus"
      @label="kuu_ratings.add_item.button"
    />
  </template>
}
