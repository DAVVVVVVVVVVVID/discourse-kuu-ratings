import { i18n } from "discourse-i18n";
import StarRating from "./star-rating";

// 评分对象帖子里每条发言（短评或对短评的回复）旁边，显示发言人给这个对象打的分
const PostScore = <template>
  {{#if @outletArgs.post.kuu_score}}
    <span
      class="kuu-post-score"
      title={{i18n
        "kuu_ratings.score.post_score"
        score=@outletArgs.post.kuu_score
      }}
    >
      <StarRating @score={{@outletArgs.post.kuu_score}} />
    </span>
  {{/if}}
</template>;

export default PostScore;
