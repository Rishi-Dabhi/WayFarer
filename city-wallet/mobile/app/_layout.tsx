import { useEffect } from "react";
import { Stack, useRouter, useSegments } from "expo-router";
import { getToken, getUser } from "@/services/storage";
import { registerPushToken, subscribeNotificationTaps } from "@/services/notificationService";
// Side-effect import: registers the background location task with TaskManager
// MUST be at the root so it's available before any background event fires
import "@/tasks/backgroundLocation";

export default function RootLayout() {
  const router = useRouter();
  const segments = useSegments();

  useEffect(() => {
    let mounted = true;

    async function check() {
      const token = await getToken();
      const user = await getUser();
      const inAuth = segments[0] === "(auth)";

      if (!mounted) return;

      if (!token) {
        if (!inAuth) router.replace("/(auth)/login");
      } else {
        const role = user?.role;
        if (inAuth) {
          router.replace(role === "merchant" ? "/(merchant)" : "/(consumer)");
        }
      }
    }

    check();

    return () => {
      mounted = false;
    };
  }, [segments]);

  useEffect(() => {
    registerPushToken().catch(() => {});
    const sub = subscribeNotificationTaps((couponId) => {
      router.push(`/(consumer)/offer/${couponId}`);
    });
    return () => sub.remove();
  }, [router]);

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: "#0F172A" } }}>
      <Stack.Screen name="(auth)" />
      <Stack.Screen name="(consumer)" />
      <Stack.Screen name="(merchant)" />
    </Stack>
  );
}
