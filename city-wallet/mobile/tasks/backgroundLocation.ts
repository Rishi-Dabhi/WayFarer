/**
 * Background location task — must be imported at the app root (_layout.tsx)
 * so it is registered before any background event fires.
 *
 * When the app is backgrounded, iOS/Android deliver location updates here.
 * We persist the latest coords to AsyncStorage; the foreground hook reads
 * them when the app resumes.
 */
import * as TaskManager from "expo-task-manager";
import AsyncStorage from "@react-native-async-storage/async-storage";

export const BACKGROUND_LOCATION_TASK = "city-wallet-bg-location";

TaskManager.defineTask(BACKGROUND_LOCATION_TASK, async ({ data, error }: TaskManager.TaskManagerTaskBody) => {
  if (error || !data) return;

  // expo-location delivers an array; take the freshest fix
  const { locations } = data as { locations: Array<{ coords: { latitude: number; longitude: number; speed: number | null }; timestamp: number }> };
  if (!locations?.length) return;

  const latest = locations[locations.length - 1];
  await AsyncStorage.setItem(
    "bg_location",
    JSON.stringify({
      lat: latest.coords.latitude,
      lng: latest.coords.longitude,
      speed: latest.coords.speed ?? 0,
      ts: latest.timestamp,
    })
  );
});
