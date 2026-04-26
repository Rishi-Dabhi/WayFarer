import { useCallback, useEffect, useState } from "react";
import api from "@/services/api";
import { Coords } from "./useLocation";

export interface MapShop {
  id: number;
  _id: string;
  name: string;
  description?: string;
  category: string;
  lat: number;
  lng: number;
  address?: string;
  distance_m: number;
  active_coupon_count: number;
  busyness: "quiet" | "normal" | "busy" | string;
  txn_count_15min: number;
}

export function useMapShops(coords: Coords, radius = 800) {
  const [shops, setShops] = useState<MapShop[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data } = await api.get("/api/shops/map", {
        params: { lat: coords.lat, lng: coords.lng, radius },
      });
      setShops(data);
    } catch {
      setError("Could not load nearby shops");
    } finally {
      setLoading(false);
    }
  }, [coords.lat, coords.lng, radius]);

  useEffect(() => {
    refresh();
    const timer = setInterval(refresh, 60_000);
    return () => clearInterval(timer);
  }, [refresh]);

  return { shops, loading, error, refresh };
}

