import { action } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import BoardItems from "../components/kuu-ratings/board-items";
import ItemHeader from "../components/kuu-ratings/item-header";
import NewBoard from "../components/kuu-ratings/modal/new-board";
import NewTopicChoice from "../components/kuu-ratings/modal/new-topic-choice";
import PostScore from "../components/kuu-ratings/post-score";
import ReviewThread, {
  START_THREAD_REPLY_EVENT,
} from "../components/kuu-ratings/review-thread";
import { START_SCORING_EVENT } from "../components/kuu-ratings/score-panel";
import StartScoringButton from "../components/kuu-ratings/start-scoring-button";
import { isBoardCategory, isItemCategory } from "../lib/kuu-ratings";

export default {
  name: "kuu-ratings",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.kuu_ratings_enabled) {
      return;
    }

    const currentUser = container.lookup("service:current-user");
    const modal = container.lookup("service:modal");

    withPluginApi((api) => {
      // 评分分类只开放回复，core 会隐藏按钮；登录用户在这里也能发起评分主题
      api.registerValueTransformer(
        "can-create-topic-button",
        ({ value, context }) =>
          value ||
          (!!currentUser && isBoardCategory(context.category?.id, siteSettings))
      );

      api.registerBehaviorTransformer(
        "create-topic-button-click",
        ({ next, context }) => {
          if (!currentUser) {
            return next();
          }

          if (isBoardCategory(context.category?.id, siteSettings)) {
            return modal.show(NewBoard);
          }

          modal.show(NewTopicChoice, { model: { createTopic: next } });
        }
      );

      api.registerReviewableComponent(
        "ReviewableKuuRatingSubmission",
        async () =>
          (await import("../components/kuu-ratings/reviewable-submission"))
            .default
      );

      api.registerReviewableStatusName(
        "ReviewableKuuRatingSubmission",
        "approved",
        "rejected"
      );

      api.renderInOutlet("topic-above-posts", BoardItems);
      api.renderInOutlet("topic-above-posts", ItemHeader);
      api.renderInOutlet(
        "topic-footer-main-buttons-before-create",
        StartScoringButton
      );
      api.renderAfterWrapperOutlet("post-meta-data-poster-name", PostScore);
      api.renderAfterWrapperOutlet("post-article", ReviewThread);

      // 楼中楼的回复在帖子流里隐藏，收进所属短评下面；
      // 短评被删除时由楼里第一条回复的位置代为显示这层楼，只隐藏它自己的正文
      api.registerValueTransformer("post-class", ({ value, context }) => {
        const post = context.post;
        if (!post?.kuu_root_review_post_id) {
          return value;
        }
        return [
          ...value,
          post.kuu_thread?.anchor ? "kuu-thread-anchor" : "kuu-thread-reply",
        ];
      });

      // core 的「N 个回复」会把回复按 Discourse 的方式展开在短评下面，和楼中楼重复
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post } }) => {
          if (isItemCategory(post?.topic?.category_id, siteSettings)) {
            dag.delete("replies");
          }
        }
      );

      // 直接回复评分对象的只能是短评，所以底部、时间线的「回复」和快捷键都改成去打分；
      // 回复某条短评或楼里的回复，在那层楼里展开小输入框，不打开发帖框
      api.modifyClass(
        "controller:topic",
        (Superclass) =>
          class extends Superclass {
            @action
            replyToPost(post) {
              if (!isItemCategory(this.model?.category_id, siteSettings)) {
                return super.replyToPost(...arguments);
              }

              if (!post || post.post_number === 1) {
                this.appEvents.trigger(START_SCORING_EVENT);
                return;
              }

              this.appEvents.trigger(START_THREAD_REPLY_EVENT, {
                rootPostId: post.kuu_root_review_post_id || post.id,
                postNumber: post.post_number,
                username: post.username,
              });
            }
          }
      );
    });
  },
};
