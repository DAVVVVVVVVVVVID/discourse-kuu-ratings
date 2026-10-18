// 和服务端 ItemFields::NAME_MAX_LENGTH、ReviewableKuuRatingSubmission::BOARD_*_ITEMS 保持一致
export const NAME_MAX_LENGTH = 30;
export const BOARD_MIN_ITEMS = 2;
export const BOARD_MAX_ITEMS = 20;
// 和服务端 RatingScore::MAX_STARS、POINTS_PER_STAR、COMMENT_MAX_LENGTH、BoardItemsQuery::SORTS 保持一致
export const STARS = 5;
export const POINTS_PER_STAR = 2;
export const MAX_SCORE = STARS * POINTS_PER_STAR;
export const COMMENT_MAX_LENGTH = 500;
export const BOARD_SORTS = ["score", "count", "latest"];
// 和服务端 ReviewThreads 保持一致：楼中楼默认显示几条、每次展开几条、回复最长多少字
export const THREAD_PREVIEW_SIZE = 3;
export const THREAD_PAGE_SIZE = 10;
export const THREAD_REPLY_MAX_LENGTH = 500;

export function boardCategoryId(siteSettings) {
  return parseInt(siteSettings.kuu_ratings_board_category, 10) || null;
}

export function itemCategoryId(siteSettings) {
  return parseInt(siteSettings.kuu_ratings_item_category, 10) || null;
}

export function isBoardCategory(categoryId, siteSettings) {
  return !!categoryId && categoryId === boardCategoryId(siteSettings);
}

export function isItemCategory(categoryId, siteSettings) {
  return !!categoryId && categoryId === itemCategoryId(siteSettings);
}

// 和服务端一样按 squish 后、不区分大小写比较
export function normalizeName(name) {
  return (name ?? "").trim().replace(/\s+/g, " ").toLowerCase();
}

export function emptyItem() {
  return { name: "", image: null, upload_id: null };
}

export function scoreForStars(stars) {
  return stars * POINTS_PER_STAR;
}
