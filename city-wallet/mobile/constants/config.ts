// Update API_BASE_URL to your local IP when testing on a physical device
export const API_BASE_URL = __DEV__
  ? (process.env.EXPO_PUBLIC_API_URL ?? "http://192.168.1.100:8000")
  : "https://your-prod-api.com";

export const MAPBOX_TOKEN = process.env.EXPO_PUBLIC_MAPBOX_TOKEN ?? "";
export const GEMMA_MODEL_URL =
  process.env.GEMMA_MODEL_URL ??
  "https://huggingface.co/lmstudio-community/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-q4_0.gguf";

export const DEMO_LAT = 48.7784;
export const DEMO_LNG = 9.1800;

// Location + movement thresholds
export const FOREGROUND_DISTANCE_INTERVAL_M = 15;   // fire watch every 15m moved
export const FOREGROUND_TIME_INTERVAL_MS    = 10_000; // Android minimum interval

export const BACKGROUND_DISTANCE_INTERVAL_M = 100;
export const BACKGROUND_TIME_INTERVAL_MS    = 300_000; // 5 min

// Speed thresholds (m/s)
export const SPEED_STATIC_MAX  = 0.4;  // below → static
export const SPEED_WALKING_MAX = 3.0;  // above → moving fast (cycling/driving)

// How far from last offer position before auto-generating a new one (walking only)
export const OFFER_TRIGGER_DISTANCE_M = 200;
// Minimum time between auto-generated offers (ms)
export const OFFER_COOLDOWN_MS = 180_000; // 3 minutes

// Static cooldown: if user hasn't moved, don't push new coords to React more than once per N ms
export const STATIC_UPDATE_INTERVAL_MS = 120_000; // 2 min
