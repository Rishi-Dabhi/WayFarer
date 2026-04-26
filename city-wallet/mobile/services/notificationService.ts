import * as Notifications from "expo-notifications";
import api from "@/services/api";

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function registerPushToken() {
  const { status } = await Notifications.requestPermissionsAsync();
  if (status !== "granted") return null;

  const token = await Notifications.getExpoPushTokenAsync();
  await api.post("/api/auth/push-token", { expo_push_token: token.data }).catch(() => {});
  return token.data;
}

export function subscribeNotificationTaps(onCoupon: (couponId: string) => void) {
  return Notifications.addNotificationResponseReceivedListener((response) => {
    const data = response.notification.request.content.data as Record<string, any>;
    if (data?.screen === "coupon" && data?.coupon_id) onCoupon(String(data.coupon_id));
  });
}

