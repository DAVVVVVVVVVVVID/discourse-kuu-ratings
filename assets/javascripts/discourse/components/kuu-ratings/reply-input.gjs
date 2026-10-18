import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { THREAD_REPLY_MAX_LENGTH } from "../../lib/kuu-ratings";

// 楼中楼里的小输入框：走 Discourse 的发帖接口（POST /posts），所以反垃圾和新用户审核照常生效；
// 最短长度由插件放宽成 1 字
export default class ReplyInput extends Component {
  @tracked flash;

  formData = { raw: "" };
  validation = `required:trim|length:1,${THREAD_REPLY_MAX_LENGTH}`;

  focusInput = modifier((element) => {
    element.querySelector("textarea")?.focus();
  });

  @action
  async submit({ raw }) {
    this.flash = null;
    // 发送期间用户可能已经点了别的「回复」，回调时要带上这次发送时的目标
    const target = this.args.target;

    try {
      const result = await ajax("/posts.json", {
        type: "POST",
        data: {
          raw,
          topic_id: this.args.topicId,
          reply_to_post_number: target.postNumber,
          // 和 core 的发帖框一样要求返回 { action, post }，才分得清发出去了还是进了审核队列
          nested_post: true,
        },
      });
      this.args.onPosted(result, target);
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  <template>
    <div class="kuu-reply-input" {{this.focusInput}}>
      {{#if this.flash}}
        <div class="alert alert-error kuu-reply-input__error">
          {{this.flash}}
        </div>
      {{/if}}

      <Form
        class="kuu-reply-input__form"
        @data={{this.formData}}
        @onSubmit={{this.submit}}
        as |form|
      >
        <form.Field
          @format="full"
          @name="raw"
          @showTitle={{false}}
          @title={{i18n "kuu_ratings.thread.reply"}}
          @type="textarea"
          @validation={{this.validation}}
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "kuu_ratings.thread.reply_placeholder"
              username=@target.username
            }}
          />
        </form.Field>

        <form.Actions>
          <form.Submit
            class="kuu-reply-input__submit"
            @label="kuu_ratings.thread.send"
          />
          <DButton
            class="btn-flat kuu-reply-input__cancel"
            @action={{@onCancel}}
            @label="cancel"
          />
        </form.Actions>
      </Form>
    </div>
  </template>
}
