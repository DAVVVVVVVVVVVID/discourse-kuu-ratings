import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import { i18n } from "discourse-i18n";
import StarRating from "./star-rating";

const LIKE = 2;

// 楼中楼里的一条回复：点赞、回复、编辑、删除、举报都用 Discourse 自带的接口和弹窗
export default class ReviewReply extends Component {
  @service currentUser;
  @service dialog;
  @service store;

  // 点过赞之后以本地状态为准，没点过时用服务端给的
  @tracked likeState = null;

  get reply() {
    return this.args.reply;
  }

  get liked() {
    return this.likeState?.liked ?? this.reply.liked;
  }

  get likeCount() {
    return this.likeState?.count ?? this.reply.like_count;
  }

  get cooked() {
    // cooked 是服务端清洗过的 HTML，和帖子正文一样直接渲染
    return trustHTML(this.reply.cooked);
  }

  get canFlag() {
    return !!this.currentUser && this.currentUser.id !== this.reply.user.id;
  }

  @action
  async toggleLike() {
    const before = { liked: this.liked, count: this.likeCount };
    const wasLiked = before.liked;
    this.likeState = {
      liked: !wasLiked,
      count: before.count + (wasLiked ? -1 : 1),
    };

    try {
      if (wasLiked) {
        await ajax(`/post_actions/${this.reply.id}`, {
          type: "DELETE",
          data: { post_action_type_id: LIKE },
        });
      } else {
        await ajax("/post_actions", {
          type: "POST",
          data: { id: this.reply.id, post_action_type_id: LIKE },
        });
      }
    } catch (error) {
      this.likeState = before;
      popupAjaxError(error);
    }
  }

  @action
  replyTo() {
    this.args.onReply({
      postNumber: this.reply.post_number,
      username: this.reply.user.username,
    });
  }

  @action
  async edit() {
    const post = await this.#postModel();
    getOwner(this).lookup("controller:topic").send("editPost", post);
  }

  @action
  async flag() {
    const post = await this.#postModel();
    getOwner(this).lookup("route:topic").send("showFlags", post);
  }

  @action
  confirmDelete() {
    this.dialog.deleteConfirm({
      message: i18n("kuu_ratings.thread.delete_confirm"),
      didConfirm: () => this.#delete(),
    });
  }

  async #delete() {
    try {
      await ajax(`/posts/${this.reply.id}`, { type: "DELETE" });
      this.args.onDeleted(this.reply);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  // 编辑和举报用的是 core 的 Post 模型
  async #postModel() {
    const topic = getOwner(this).lookup("controller:topic").model;
    const loaded = topic?.postStream?.findLoadedPost(this.reply.id);
    if (loaded) {
      return loaded;
    }

    const json = await ajax(`/posts/${this.reply.id}.json`);
    const post = this.store.createRecord("post", json);
    post.set("topic", topic);
    return post;
  }

  <template>
    <li
      class="kuu-review-reply {{if @highlighted '--highlighted'}}"
      data-post-number={{this.reply.post_number}}
    >
      <DUserAvatar @size="small" @user={{this.reply.user}} />
      <div class="kuu-review-reply__main">
        <div class="kuu-review-reply__header">
          <span class="kuu-review-reply__username">
            {{this.reply.user.username}}
          </span>
          {{#if this.reply.kuu_score}}
            <StarRating @score={{this.reply.kuu_score}} />
          {{/if}}
        </div>

        <div class="kuu-review-reply__body">
          {{#if this.reply.reply_to_username}}
            <span class="kuu-review-reply__reply-to">
              {{i18n
                "kuu_ratings.thread.reply_to"
                username=this.reply.reply_to_username
              }}
            </span>
          {{/if}}
          <div class="kuu-review-reply__cooked cooked">{{this.cooked}}</div>
        </div>

        <div class="kuu-review-reply__actions">
          <DRelativeDate @date={{this.reply.created_at}} />

          {{#if this.reply.can_like}}
            <DButton
              class="btn-transparent btn-small kuu-review-reply__like
                {{if this.liked '--liked'}}"
              aria-pressed={{if this.liked "true" "false"}}
              @action={{this.toggleLike}}
              @icon={{if this.liked "d-liked" "d-unliked"}}
              @title="kuu_ratings.thread.like"
              @translatedLabel={{if this.likeCount this.likeCount}}
            />
          {{else if this.likeCount}}
            <span class="kuu-review-reply__like-count">
              {{this.likeCount}}
            </span>
          {{/if}}

          {{#if @canReply}}
            <DButton
              class="btn-transparent btn-small kuu-review-reply__reply"
              @action={{this.replyTo}}
              @label="kuu_ratings.thread.reply"
            />
          {{/if}}

          {{#if this.reply.can_edit}}
            <DButton
              class="btn-transparent btn-small kuu-review-reply__edit"
              @action={{this.edit}}
              @label="kuu_ratings.thread.edit"
            />
          {{/if}}

          {{#if this.reply.can_delete}}
            <DButton
              class="btn-transparent btn-small kuu-review-reply__delete"
              @action={{this.confirmDelete}}
              @label="kuu_ratings.thread.delete"
            />
          {{/if}}

          {{#if this.canFlag}}
            <DButton
              class="btn-transparent btn-small kuu-review-reply__flag"
              @action={{this.flag}}
              @label="kuu_ratings.thread.flag"
            />
          {{/if}}
        </div>
      </div>
    </li>
  </template>
}
