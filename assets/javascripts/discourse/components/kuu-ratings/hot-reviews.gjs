import { trustHTML } from "@ember/template";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import StarRating from "./star-rating";

// cooked 是服务端清洗过的 HTML，和帖子正文一样直接渲染
const cooked = (review) => trustHTML(review.cooked);
const postUrl = (topicUrl, review) => `${topicUrl}/${review.post_number}`;

const HotReviews = <template>
  <section class="kuu-hot-reviews">
    <h2 class="kuu-hot-reviews__title">{{i18n "kuu_ratings.hot_reviews"}}</h2>
    <ul class="kuu-hot-reviews__list">
      {{#each @reviews key="post_id" as |review|}}
        <li class="kuu-hot-review">
          <div class="kuu-hot-review__header">
            <DUserAvatar @size="small" @user={{review.user}} />
            <span class="kuu-hot-review__username">
              {{review.user.username}}
            </span>
            <StarRating @score={{review.score}} />
            <a
              class="kuu-hot-review__stats"
              href={{postUrl @topicUrl review}}
              title={{i18n "kuu_ratings.view_post"}}
            >
              <span
                class="kuu-hot-review__likes"
                title={{i18n "kuu_ratings.thread.likes"}}
              >
                {{dIcon "heart"}}
                {{review.like_count}}
              </span>
              <span
                class="kuu-hot-review__replies"
                title={{i18n "kuu_ratings.thread.replies"}}
              >
                {{dIcon "far-comment"}}
                {{review.reply_count}}
              </span>
            </a>
          </div>
          <div class="kuu-hot-review__body cooked">{{cooked review}}</div>
        </li>
      {{/each}}
    </ul>
  </section>
</template>;

export default HotReviews;
