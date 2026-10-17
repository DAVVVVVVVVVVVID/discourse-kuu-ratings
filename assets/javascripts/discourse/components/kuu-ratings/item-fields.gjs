import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";
import { i18n } from "discourse-i18n";
import { NAME_MAX_LENGTH } from "../../lib/kuu-ratings";

// 一个评分对象的图片和名称。@fields 可以是表单本身，也可以是 Collection 的一项
export default class ItemFields extends Component {
  nameValidation = `required:trim|length:1,${NAME_MAX_LENGTH}`;
  // FormKit 的 image 控件拿字段名拼元素 id 再当选择器用，Collection 里的字段名带点号会出错
  uploaderId = `kuu-item-image-${dUniqueId()}`;

  @action
  setImage(upload, { set, parentName }) {
    const prefix = parentName ? `${parentName}.` : "";
    set(`${prefix}image`, upload?.url ?? null);
    set(`${prefix}upload_id`, upload?.id ?? null);
  }

  <template>
    <div class="kuu-item-fields">
      <@fields.Field
        class="kuu-item-fields__image"
        @name="image"
        @onSet={{this.setImage}}
        @showTitle={{false}}
        @title={{i18n "kuu_ratings.item_form.image"}}
        @type="custom"
        @validation="required"
        as |field|
      >
        <field.Control>
          <UppyImageUploader
            class="kuu-item-fields__uploader"
            @id={{this.uploaderId}}
            @imageUrl={{field.value}}
            @onUploadDeleted={{fn field.set null}}
            @onUploadDone={{field.set}}
            @previewSize="cover"
            @type="composer"
          />
        </field.Control>
      </@fields.Field>

      <@fields.Field
        class="kuu-item-fields__name"
        @format="full"
        @name="name"
        @title={{if
          @number
          (i18n "kuu_ratings.item_form.numbered_name" number=@number)
          (i18n "kuu_ratings.item_form.name")
        }}
        @type="input"
        @validation={{this.nameValidation}}
        as |field|
      >
        <field.Control
          placeholder={{i18n "kuu_ratings.item_form.name_placeholder"}}
        />
      </@fields.Field>

      {{#if (has-block)}}
        <div class="kuu-item-fields__actions">{{yield}}</div>
      {{/if}}
    </div>
  </template>
}
