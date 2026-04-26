import { useState, useEffect, useCallback } from "react";
import api from "@/services/api";
import { Coords } from "./useLocation";
import { SIGNAL_REFRESH_MS } from "@/constants/config";

export interface ContextSignals {
  weather: { temp: number; feels_like: number; condition: string; icon: string };
  time: { hour: number; period: string; day_of_week: string };
  nearby_shops: Array<{ shop_id: number; name: string; distance_m: number; busyness: string; txn_count_15min: number }>;
  local_events: Array<{ name: string; distance_m: number; date?: string }>;
  osm_density: { total: number; by_category: Record<string, number>; closest: Array<{ name: string; category: string; distance_m: number }> };
}

export function useContextSignals(coords: Coords, demo?: string) {
  const [signals, setSignals] = useState<ContextSignals | null>(null);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    try {
      const params: Record<string, string | number> = { lat: coords.lat, lng: coords.lng };
      if (demo) params.demo = demo;
      const { data } = await api.get("/api/context/signals", { params });
      setSignals(data);
    } catch {
      // keep last
    } finally {
      setLoading(false);
    }
  }, [coords.lat, coords.lng, demo]);

  useEffect(() => {
    fetch();
    const interval = setInterval(fetch, SIGNAL_REFRESH_MS);
    return () => clearInterval(interval);
  }, [fetch]);

  return { signals, loading, refresh: fetch };
}
