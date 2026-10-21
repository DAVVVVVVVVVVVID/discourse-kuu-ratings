import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getURLWithCDN } from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// 帖子列表里评分主题标题下面的一排评分对象（Issue #4）：最多 4 个（图、名、★分数），最右边「查看更多」。
// 标题本身还是 core 的链接（键盘浏览列表、未读标记都照常），这里只画标题下面的部分。
// 不包 core 的 topic-link：那是包裹型 outlet，只能有一个插件用，二手市场插件已经在用了
export default class BoardCard extends Component {
  static shouldRender({ topic }) {
    return !!topic?.kuu_rating_board_card;
  }

  @service siteSettings;

  get topic() {
    return this.args.outletArgs.topic;
  }

  get items() {
    const placeholder = this.siteSettings.kuu_ratings_placeholder_image;

    return this.topic.kuu_rating_board_card.items.map((item) => {
      const image = item.image_url || placeholder;
      return {
        id: item.id,
        title: item.title,
        url: item.url,
        // 没有图片、站点设置里也没上传占位图时，显示灰色图标
        imageUrl: image ? getURLWithCDN(image) : null,
        hasScores: item.score_count > 0,
        scoreText: item.score_avg?.toFixed(1),
      };
    });
  }

  <template>
    <div class="kuu-board-card">
      <ul
        class="kuu-board-card__items"
        aria-label={{i18n "kuu_ratings.board.items_title"}}
      >
        {{#each this.items key="id" as |item|}}
          <li class="kuu-board-card__item">
            <a class="kuu-board-card__link" href={{item.url}}>
              <span class="kuu-board-card__image">
                {{#if item.imageUrl}}
                  <img
                    alt=""
                    decoding="async"
                    loading="lazy"
                    src={{item.imageUrl}}
                  />
                {{else}}
                  {{dIcon "image"}}
                {{/if}}
              </span>
              <span class="kuu-board-card__name">{{item.title}}</span>
              {{#if item.hasScores}}
                <span class="kuu-board-card__score">
                  {{dIcon "star"}}
                  {{item.scoreText}}
                </span>
              {{else}}
                <span class="kuu-board-card__score --none">
                  {{i18n "kuu_ratings.board.no_scores"}}
                </span>
              {{/if}}
            </a>
          </li>
        {{/each}}
        <li class="kuu-board-card__item --more">
          <a class="kuu-board-card__more" href={{this.topic.url}}>
            <span class="kuu-board-card__more-text">
              {{i18n "kuu_ratings.board_card.more"}}
            </span>
            {{dIcon "angle-right"}}
          </a>
        </li>
      </ul>
    </div>
  </template>
}
