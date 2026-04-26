import { useState, useEffect, useRef, useCallback } from "react";
import { AppState, AppStateStatus } from "react-native";
import * as Location from "expo-location";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { BACKGROUND_LOCATION_TASK } from "@/tasks/backgroundLocation";
import {
  DEMO_LAT, DEMO_LNG,
  FOREGROUND_DISTANCE_INTERVAL_M, FOREGROUND_TIME_INTERVAL_MS,
  BACKGROUND_DISTANCE_INTERVAL_M, BACKGROUND_TIME_INTERVAL_MS,
  SPEED_STATIC_MAX, SPEED_WALKING_MAX,
  OFFER_TRIGGER_DISTANCE_M, OFFER_COOLDOWN_MS,
  STATIC_UPDATE_INTERVAL_MS,
} from "@/constants/config";

export type MovementState = "static" | "walking" | "moving_fast";

export interface Coords { lat: number; lng: number }

export interface LocationResult {
  coords: Coords;
  movementState: MovementState;
  shouldAutoGenerate: boolean;
  markOfferGenerated: () => void;
}

function haversineM(a: Coords, b: Coords): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

function classifySpeed(speed: number | null | undefined): MovementState {
  const s = speed ?? 0;
  if (s < 0) return "static";           // -1 means invalid on iOS
  if (s < SPEED_STATIC_MAX) return "static";
  if (s < SPEED_WALKING_MAX) return "walking";
  return "moving_fast";
}

export function useLocation(): LocationResult {
  const [coords, setCoords] = useState<Coords>({ lat: DEMO_LAT, lng: DEMO_LNG });
  const [movementState, setMovementState] = useState<MovementState>("static");
  const [shouldAutoGenerate, setShouldAutoGenerate] = useState(false);

  // Refs so callbacks always see fresh values without causing re-subscriptions
  const lastOfferCoords = useRef<Coords | null>(null);
  const lastOfferTs = useRef<number>(0);
  const lastStaticUpdateTs = useRef<number>(0);
  const watchSub = useRef<Location.LocationSubscription | null>(null);

  const markOfferGenerated = useCallback(() => {
    setShouldAutoGenerate(false);
    lastOfferCoords.current = coords;
    lastOfferTs.current = Date.now();
  }, [coords]);

  // ── Core location update handler ──────────────────────────────────────────
  function handleLocationUpdate(loc: Location.LocationObject) {
    const next: Coords = { lat: loc.coords.latitude, lng: loc.coords.longitude };
    const speed = loc.coords.speed;
    const state = classifySpeed(speed);

    setMovementState(state);

    // Static: throttle React state updates to avoid pointless re-renders
    if (state === "static") {
      const now = Date.now();
      if (now - lastStaticUpdateTs.current < STATIC_UPDATE_INTERVAL_MS) return;
      lastStaticUpdateTs.current = now;
      setCoords(next);
      return;
    }

    // Walking or moving: always update coords
    setCoords(next);

    // Auto-generate gate: only while walking, respecting distance + cooldown
    if (state === "walking") {
      const base = lastOfferCoords.current ?? next;
      const dist = haversineM(base, next);
      const elapsed = Date.now() - lastOfferTs.current;
      if (dist >= OFFER_TRIGGER_DISTANCE_M && elapsed >= OFFER_COOLDOWN_MS) {
        setShouldAutoGenerate(true);
      }
    }
  }

  // ── Foreground watch ───────────────────────────────────────────────────────
  async function startForegroundWatch() {
    if (watchSub.current) return; // already watching
    watchSub.current = await Location.watchPositionAsync(
      {
        accuracy: Location.Accuracy.Balanced,
        distanceInterval: FOREGROUND_DISTANCE_INTERVAL_M,
        timeInterval: FOREGROUND_TIME_INTERVAL_MS,
      },
      handleLocationUpdate
    );
  }

  function stopForegroundWatch() {
    watchSub.current?.remove();
    watchSub.current = null;
  }

  // ── Background task ────────────────────────────────────────────────────────
  async function startBackgroundTask() {
    const already = await Location.hasStartedLocationUpdatesAsync(BACKGROUND_LOCATION_TASK).catch(() => false);
    if (already) return;
    await Location.startLocationUpdatesAsync(BACKGROUND_LOCATION_TASK, {
      accuracy: Location.Accuracy.Low,
      distanceInterval: BACKGROUND_DISTANCE_INTERVAL_M,
      timeInterval: BACKGROUND_TIME_INTERVAL_MS,
      showsBackgroundLocationIndicator: true,
      foregroundService: {
        notificationTitle: "City Wallet",
        notificationBody: "Tracking your location for nearby offers",
        notificationColor: "#3B82F6",
      },
    });
  }

  async function stopBackgroundTask() {
    const running = await Location.hasStartedLocationUpdatesAsync(BACKGROUND_LOCATION_TASK).catch(() => false);
    if (running) await Location.stopLocationUpdatesAsync(BACKGROUND_LOCATION_TASK);
  }

  // ── Resume from background: sync coords from AsyncStorage ─────────────────
  async function syncFromBackground() {
    try {
      const raw = await AsyncStorage.getItem("bg_location");
      if (!raw) return;
      const saved = JSON.parse(raw) as { lat: number; lng: number; speed: number; ts: number };
      // Only use if recent enough (< 10 min old)
      if (Date.now() - saved.ts < 600_000) {
        setCoords({ lat: saved.lat, lng: saved.lng });
        setMovementState(classifySpeed(saved.speed));
      }
    } catch { /* ignore */ }
  }

  // ── AppState: foreground ↔ background handoff ──────────────────────────────
  useEffect(() => {
    function onAppStateChange(next: AppStateStatus) {
      if (next === "active") {
        syncFromBackground();
        startForegroundWatch();
        stopBackgroundTask();
      } else if (next === "background") {
        stopForegroundWatch();
        startBackgroundTask();
      }
    }
    const sub = AppState.addEventListener("change", onAppStateChange);
    return () => sub.remove();
  }, []);

  // ── Initial setup ──────────────────────────────────────────────────────────
  useEffect(() => {
    let cancelled = false;

    async function init() {
      // Request foreground permission
      const { status: fgStatus } = await Location.requestForegroundPermissionsAsync();
      if (fgStatus !== "granted" || cancelled) return;

      // Kick off foreground watch immediately
      await startForegroundWatch();

      // Request background permission (best-effort — user may deny)
      const { status: bgStatus } = await Location.requestBackgroundPermissionsAsync();
      if (bgStatus !== "granted" || cancelled) return;
      // Background task is started on first actual backgrounding (see AppState handler)
    }

    init();

    return () => {
      cancelled = true;
      stopForegroundWatch();
      // Leave background task running — it's managed by the OS lifecycle
    };
  }, []);

  return { coords, movementState, shouldAutoGenerate, markOfferGenerated };
}
