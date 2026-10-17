import { action } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import BoardItems from "../components/kuu-ratings/board-items";
import ItemHeader from "../components/kuu-ratings/item-header";
import NewBoard from "../components/kuu-ratings/modal/new-board";
import NewTopicChoice from "../components/kuu-ratings/modal/new-topic-choice";
import PostScore from "../components/kuu-ratings/post-score";
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

      // 直接回复评分对象的只能是短评，所以底部、时间线的「回复」和快捷键都改成去打分；
      // 回复某条短评照常打开发帖框
      api.modifyClass(
        "controller:topic",
        (Superclass) =>
          class extends Superclass {
            @action
            replyToPost(post) {
              if (
                isItemCategory(this.model?.category_id, siteSettings) &&
                (!post || post.post_number === 1)
              ) {
                this.appEvents.trigger(START_SCORING_EVENT);
                return;
              }

              return super.replyToPost(...arguments);
            }
          }
      );
    });
  },
};
