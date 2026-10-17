import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import bodyClass from "discourse/helpers/body-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";
import { BOARD_SORTS, isBoardCategory } from "../../lib/kuu-ratings";
import AddItemButton from "./add-item-button";
import BoardItemRow from "./board-item-row";

const sortLabel = (sort) => `kuu_ratings.board.sorts.${sort}`;

// 评分主题页：首帖隐藏（只有插件生成的固定文字），标题下面直接是评分对象列表
export default class BoardItems extends Component {
  static shouldRender({ model }, { siteSettings }) {
    return isBoardCategory(model?.category_id, siteSettings);
  }

  @service currentUser;

  @tracked items = [];
  @tracked loadedKey;
  @tracked sort = BOARD_SORTS[0];

  sorts = BOARD_SORTS;

  loadItems = modifier((element, [boardId, sort]) => {
    this.#load(boardId, sort);
  });

  get board() {
    return this.args.outletArgs.model;
  }

  get isLoading() {
    return this.loadedKey !== this.#key(this.board.id, this.sort);
  }

  get canAddItem() {
    return !!this.currentUser && !this.board.closed && !this.board.archived;
  }

  @action
  changeSort(sort) {
    this.sort = sort;
  }

  async #load(boardId, sort) {
    const key = this.#key(boardId, sort);

    try {
      const { items } = await ajax(
        `/kuu-ratings/boards/${boardId}/items.json`,
        {
          data: { sort },
        }
      );

      // 期间换了排序或者换了评分主题，旧请求的结果丢掉
      if (key !== this.#key(this.board.id, this.sort)) {
        return;
      }
      this.items = items;
      this.loadedKey = key;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #key(boardId, sort) {
    return `${boardId}:${sort}`;
  }

  <template>
    {{bodyClass "kuu-board-topic"}}

    <section class="kuu-board-items" {{this.loadItems this.board.id this.sort}}>
      <div class="kuu-board-items__header">
        <h2 class="kuu-board-items__title">
          {{i18n "kuu_ratings.board.items_title"}}
        </h2>

        <div
          class="kuu-board-items__sorts"
          role="group"
          aria-label={{i18n "kuu_ratings.board.sort_label"}}
        >
          {{#each this.sorts as |sort|}}
            <DButton
              class="btn-flat kuu-board-items__sort
                {{if (eq sort this.sort) '--active'}}"
              aria-pressed={{if (eq sort this.sort) "true" "false"}}
              @action={{fn this.changeSort sort}}
              @label={{sortLabel sort}}
            />
          {{/each}}
        </div>

        {{#if this.canAddItem}}
          <AddItemButton @board={{this.board}} />
        {{/if}}
      </div>

      {{#if this.isLoading}}
        {{dLoadingSpinner}}
      {{else if this.items.length}}
        <ul class="kuu-board-items__list">
          {{#each this.items key="id" as |item|}}
            <BoardItemRow @item={{item}} />
          {{/each}}
        </ul>
      {{else}}
        <p class="kuu-board-items__empty">
          {{i18n "kuu_ratings.board.empty"}}
        </p>
      {{/if}}
    </section>
  </template>
}
