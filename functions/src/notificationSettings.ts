/**
 * 알림 설정 helper (Phase 3c-3).
 *
 * users/{uid}.notificationSettings 의 카테고리별 on/off 를 읽는다.
 * 키 부재 / 비boolean 이면 DEFAULTS 로 fallback (마이그레이션 불필요).
 *
 * ⚠️ 기본값은 클라이언트 `NotificationCategory.defaultValue` /
 *    `NotificationSettingsEntity` 의 @Default 와 반드시 일치해야 한다.
 */

export const NOTIFICATION_SETTING_DEFAULTS = {
  orderProgress: true,
  pickupComplete: false, // 결정 B — 기존 사용자에게 의도 없는 신규 알림 금지
  newOrder: true,
  refundRequest: true,
} as const;

export type NotificationSettingKey = keyof typeof NOTIFICATION_SETTING_DEFAULTS;

export function isNotificationEnabled(
  userData: Record<string, unknown> | undefined,
  key: NotificationSettingKey
): boolean {
  const settings = userData?.notificationSettings;
  if (settings && typeof settings === "object") {
    const value = (settings as Record<string, unknown>)[key];
    if (typeof value === "boolean") return value;
  }
  return NOTIFICATION_SETTING_DEFAULTS[key];
}
