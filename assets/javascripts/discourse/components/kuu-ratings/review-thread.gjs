import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { THREAD_PREVIEW_SIZE } from "../../lib/kuu-ratings";
import ReplyInput from "./reply-input";
import ReviewReply from "./review-reply";

export const START_THREAD_REPLY_EVENT = "kuu-ratings:start-thread-reply";

// core 打开帖子链接时会把页面锁在目标帖子上约 1 秒（lib/lock-on.js 的 LOCK_DURATION_MS）。
// 楼里的回复在帖子流里是隐藏的，锁的位置不对，要等锁结束再滚到楼里那条回复
const AFTER_CORE_LOCK_MS = 1200;

// 一条短评下面的楼中楼。回复本身是普通回帖，在帖子流里被隐藏，收到这里显示。
// 短评被删除时，由楼里第一条回复的位置代为显示（短评本身不会发给普通用户）
export default class ReviewThread extends Component {
  static shouldRender({ post }) {
    return !!post.kuu_thread;
  }

  @service appEvents;
  @service router;
  @service toasts;

  @tracked replies = [...this.thread.replies];
  @tracked replyCount = this.thread.reply_count;
  @tracked target = null;
  @tracked isLoading = false;
  @tracked highlightedPostNumber = null;

  listen = modifier(() => {
    this.appEvents.on(START_THREAD_REPLY_EVENT, this, this.#onStartReply);
    return () =>
      this.appEvents.off(START_THREAD_REPLY_EVENT, this, this.#onStartReply);
  });

  // 从「某某回复了你」的通知点进来时，展开到那条回复并高亮
  focusLinkedReply = modifier((element) => {
    this.#focusLinkedReply(element);
    return () => cancel(this.#scrollTimer);
  });

  #scrollTimer;

  get post() {
    return this.args.outletArgs.post;
  }

  get thread() {
    return this.post.kuu_thread;
  }

  get rootPostId() {
    return this.thread.root_post_id;
  }

  // 工作人员能看到已删除的短评本身，楼就显示在它下面，不用第一条回复代为显示
  get isVisible() {
    if (!this.thread.anchor) {
      return true;
    }
    return !this.post.topic?.postStream?.findLoadedPost(this.rootPostId);
  }

  get hasMore() {
    return this.replies.length < this.replyCount;
  }

  get moreLabel() {
    return this.replies.length <= THREAD_PREVIEW_SIZE
      ? i18n("kuu_ratings.thread.view_all", { count: this.replyCount })
      : i18n("kuu_ratings.thread.view_more");
  }

  get canReply() {
    return this.thread.can_reply;
  }

  @action
  startReply(target) {
    this.target = target;
  }

  @action
  cancelReply() {
    this.target = null;
  }

  @action
  async loadMore() {
    this.isLoading = true;

    try {
      const result = await ajax(
        `/kuu-ratings/reviews/${this.rootPostId}/replies.json`,
        { data: { offset: this.replies.length } }
      );
      const known = new Set(this.replies.map((reply) => reply.id));
      this.replies = [
        ...this.replies,
        ...result.replies.filter((reply) => !known.has(reply.id)),
      ];
      this.replyCount = result.reply_count;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  onPosted(result, target) {
    if (this.target === target) {
      this.target = null;
    }

    if (result.action === "enqueued") {
      this.toasts.success({
        data: { message: i18n("kuu_ratings.thread.enqueued") },
      });
      return;
    }

    this.replies = [...this.replies, this.#replyFromPost(result.post, target)];
    this.replyCount += 1;
  }

  @action
  onDeleted(deleted) {
    this.replies = this.replies.filter((reply) => reply.id !== deleted.id);
    this.replyCount -= 1;
  }

  #onStartReply({ rootPostId, postNumber, username }) {
    if (rootPostId === this.rootPostId && this.canReply) {
      this.target = { postNumber, username };
    }
  }

  // 发帖接口返回的是 core 的帖子数据，转成楼里回复的格式
  #replyFromPost(post, target) {
    return {
      id: post.id,
      post_number: post.post_number,
      cooked: post.cooked,
      created_at: post.created_at,
      like_count: 0,
      liked: false,
      can_like: false,
      can_edit: post.can_edit,
      can_delete: post.can_delete,
      kuu_score: post.kuu_score,
      reply_to_username:
        target.postNumber === this.post.post_number || this.thread.anchor
          ? null
          : target.username,
      user: {
        id: post.user_id,
        username: post.username,
        name: post.name,
        avatar_template: post.avatar_template,
      },
    };
  }

  async #focusLinkedReply(element) {
    const postNumber = parseInt(this.router.currentRoute?.params?.nearPost, 10);
    const linked = this.post.topic?.postStream?.posts?.find(
      (post) => post.post_number === postNumber
    );
    if (!linked || linked.kuu_root_review_post_id !== this.rootPostId) {
      return;
    }

    while (
      this.hasMore &&
      !this.replies.some((reply) => reply.post_number === postNumber)
    ) {
      await this.loadMore();
    }

    this.highlightedPostNumber = postNumber;
    this.#scrollTimer = discourseLater(() => {
      element
        .querySelector(`[data-post-number="${postNumber}"]`)
        ?.scrollIntoView({ block: "center" });
    }, AFTER_CORE_LOCK_MS);
  }

  <template>
    {{#if this.isVisible}}
      <section
        class="kuu-review-thread {{if this.thread.anchor '--anchor'}}"
        data-root-post-id={{this.rootPostId}}
        {{this.listen}}
        {{this.focusLinkedReply}}
      >
        {{#if this.thread.root_deleted}}
          <p class="kuu-review-thread__deleted">
            {{i18n "kuu_ratings.thread.review_deleted"}}
          </p>
        {{/if}}

        {{#if this.replies.length}}
          <ul class="kuu-review-thread__replies">
            {{#each this.replies key="id" as |reply|}}
              <ReviewReply
                @canReply={{this.canReply}}
                @highlighted={{eq reply.post_number this.highlightedPostNumber}}
                @onDeleted={{this.onDeleted}}
                @onReply={{this.startReply}}
                @reply={{reply}}
              />
            {{/each}}
          </ul>
        {{/if}}

        {{#if this.hasMore}}
          <DButton
            class="btn-transparent btn-small kuu-review-thread__more"
            @action={{this.loadMore}}
            @isLoading={{this.isLoading}}
            @translatedLabel={{this.moreLabel}}
          />
        {{/if}}

        {{#if this.target}}
          <ReplyInput
            @onCancel={{this.cancelReply}}
            @onPosted={{this.onPosted}}
            @target={{this.target}}
            @topicId={{this.post.topic_id}}
          />
        {{/if}}
      </section>
    {{/if}}
  </template>
}
