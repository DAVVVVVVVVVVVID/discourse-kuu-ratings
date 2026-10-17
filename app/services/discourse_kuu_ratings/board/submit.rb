# frozen_string_literal: true

module DiscourseKuuRatings
  # 提交一个新的评分主题（只有名称）和至少 2 个评分对象（图片 + 名称），整体进审核队列
  class Board::Submit
    include Service::Base

    params do
      attribute :title, :string
      attribute :items, :array do
        attribute :name, :string
        attribute :upload_id, :integer

        # 名称会写进首帖的图片 Markdown，换行会跳出图片语法、注入 @提及和链接
        before_validation { self.name = name&.squish }

        validates :name, presence: true, length: { maximum: ItemFields::NAME_MAX_LENGTH }
        validates :upload_id, presence: true
      end

      before_validation { self.title = title&.squish }

      validates :title, presence: true, length: { maximum: ItemFields::NAME_MAX_LENGTH }
      validates :items,
                length: {
                  minimum: ReviewableKuuRatingSubmission::BOARD_MIN_ITEMS,
                  maximum: ReviewableKuuRatingSubmission::BOARD_MAX_ITEMS,
                }
      validate :item_names_are_unique

      def names
        [title, *items.map(&:name)]
      end

      def upload_ids
        items.map(&:upload_id)
      end

      private

      def item_names_are_unique
        # 父级校验先于子项的 squish 执行，这里要自己压缩空格；items 缺失时交给长度校验报错
        item_names = Array(items).map { |item| item.name.to_s.squish.downcase }
        return if item_names.uniq.size == item_names.size

        errors.add(:items, I18n.t("kuu_ratings.errors.duplicate_names"))
      end
    end

    model :board_category
    policy :can_see_board_category
    policy :submitter_is_active, class_name: Submission::Policy::SubmitterIsActive
    policy :no_blocked_words, class_name: Submission::Policy::NoBlockedWords
    model :uploads
    policy :own_images, class_name: Submission::Policy::OwnImages

    transaction do
      model :submission, :create_submission
      step :queue_for_review
    end

    private

    def fetch_board_category
      Category.find_by(id: ItemFields.board_category_id)
    end

    def can_see_board_category(guardian:, board_category:)
      guardian.can_see_category?(board_category)
    end

    def fetch_uploads(params:)
      Upload.where(id: params.upload_ids).to_a
    end

    def create_submission(guardian:, params:)
      ReviewableKuuRatingSubmission.submit!(
        submitter: guardian.user,
        payload: {
          board_title: params.title,
          items: params.items.map { |item| { name: item.name, upload_id: item.upload_id } },
        },
      )
    end

    def queue_for_review(submission:)
      submission.queue_for_review!
    end
  end
end
