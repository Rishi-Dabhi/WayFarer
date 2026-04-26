import { useEffect, useRef, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import MapboxGL from "@rnmapbox/maps";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import api from "@/services/api";
import { getUser } from "@/services/storage";
import { MAPBOX_TOKEN } from "@/constants/config";
import { useLocation } from "@/hooks/useLocation";
import { useContextSignals } from "@/hooks/useContextSignals";
import { useMapShops, MapShop } from "@/hooks/useMapShops";
import ContextStatusBar from "@/components/shared/ContextStatusBar";

if (MAPBOX_TOKEN) {
  MapboxGL.setAccessToken(MAPBOX_TOKEN);
}

const BUSYNESS_COLOR: Record<string, string> = {
  quiet: "#22C55E",
  normal: "#F59E0B",
  busy: "#EF4444",
};

const MOVEMENT_LABEL: Record<string, string> = {
  static: "Standing still",
  walking: "Walking",
  moving_fast: "Moving fast",
};

const RADIUS_OPTIONS = [200, 500, 1000, 2000] as const;
type Radius = typeof RADIUS_OPTIONS[number];

function radiusLabel(r: Radius) {
  return r >= 1000 ? `${r / 1000}km` : `${r}m`;
}

export default function ConsumerMapHome() {
  const router = useRouter();
  const { coords, movementState } = useLocation();
  const [radius, setRadius] = useState<Radius>(500);
  const { signals } = useContextSignals(coords);
  const { shops, loading, error, refresh } = useMapShops(coords, radius);
  const [selected, setSelected] = useState<MapShop | null>(null);
  const [autoStatus, setAutoStatus] = useState<string | null>(null);
  const lastAutoCheck = useRef(0);
  const lastVisitPing = useRef(0);

  useEffect(() => {
    if (!selected && shops.length > 0) setSelected(shops[0]);
  }, [shops, selected]);

  useEffect(() => {
    async function checkAutoCoupons() {
      const now = Date.now();
      if (now - lastAutoCheck.current < 45_000) return;
      lastAutoCheck.current = now;

      const user = await getUser();
      const { data } = await api.post("/api/coupons/auto-nearby", {
        lat: coords.lat,
        lng: coords.lng,
        user_id: user?.user_id ? Number(user.user_id) : undefined,
        radius_m: radius,
      });

      if (data.count > 0) {
        setAutoStatus(`${data.count} new offer${data.count === 1 ? "" : "s"} unlocked nearby`);
        refresh();
      }
    }

    checkAutoCoupons().catch(() => {});
  }, [coords.lat, coords.lng, refresh]);

  useEffect(() => {
    async function trackStoreVisit() {
      const now = Date.now();
      if (now - lastVisitPing.current < 30_000) return;
      lastVisitPing.current = now;

      await api.post("/api/shops/visit-ping", {
        lat: coords.lat,
        lng: coords.lng,
        radius_m: 40,
      });
    }

    trackStoreVisit().catch(() => {});
  }, [coords.lat, coords.lng]);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>WayFarer</Text>
          <Text style={styles.sub}>Nearby rewards around you</Text>
        </View>
        <TouchableOpacity style={styles.refresh} onPress={refresh}>
          {loading ? <ActivityIndicator color="#F8FAFC" size="small" /> : <Ionicons name="refresh" size={18} color="#F8FAFC" />}
        </TouchableOpacity>
      </View>

      <View style={styles.radiusRow}>
        {RADIUS_OPTIONS.map((r) => (
          <TouchableOpacity
            key={r}
            style={[styles.radiusChip, radius === r && styles.radiusChipActive]}
            onPress={() => setRadius(r)}
          >
            <Text style={[styles.radiusChipText, radius === r && styles.radiusChipTextActive]}>
              {radiusLabel(r)}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <ContextStatusBar signals={signals} />

      <View style={styles.mapPanel}>
        {MAPBOX_TOKEN ? (
          <MapboxGL.MapView style={styles.map} styleURL={MapboxGL.StyleURL.Street}>
            <MapboxGL.Camera
              zoomLevel={15}
              centerCoordinate={[coords.lng, coords.lat]}
              animationMode="flyTo"
              animationDuration={600}
            />
            <MapboxGL.UserLocation visible />

            {shops.map((shop) => (
              <MapboxGL.PointAnnotation
                key={shop.id}
                id={`shop-${shop.id}`}
                coordinate={[shop.lng, shop.lat]}
                onSelected={() => setSelected(shop)}
              >
                <TouchableOpacity
                  activeOpacity={0.85}
                  style={[styles.pin, { borderColor: BUSYNESS_COLOR[shop.busyness] ?? "#38BDF8" }]}
                  onPress={() => setSelected(shop)}
                >
                  <Ionicons name="storefront" size={17} color="#F8FAFC" />
                  <View style={styles.pinBadge}>
                    <Text style={styles.pinBadgeText}>{shop.active_coupon_count}</Text>
                  </View>
                </TouchableOpacity>
              </MapboxGL.PointAnnotation>
            ))}
          </MapboxGL.MapView>
        ) : (
          <View style={[styles.map, styles.mapFallback]}>
            <Text style={styles.empty}>Set EXPO_PUBLIC_MAPBOX_TOKEN to show Mapbox.</Text>
          </View>
        )}
      </View>

      <View style={styles.moveBadge}>
        <Ionicons name={movementState === "walking" ? "walk" : movementState === "moving_fast" ? "bicycle" : "pause-circle"} size={13} color="#CBD5E1" />
        <Text style={styles.moveText}>{MOVEMENT_LABEL[movementState]}</Text>
      </View>
      {autoStatus && <Text style={styles.autoStatus}>{autoStatus}</Text>}

      <ScrollView style={styles.sheet} contentContainerStyle={styles.sheetContent}>
        {error ? <Text style={styles.error}>{error}</Text> : null}
        {selected ? (
          <View style={styles.selectedCard}>
            <View style={styles.sheetHead}>
              <View style={{ flex: 1 }}>
                <Text style={styles.shopName}>{selected.name}</Text>
                <Text style={styles.shopMeta}>
                  {selected.category} · {selected.distance_m}m · {selected.busyness}
                </Text>
              </View>
              <View style={styles.countPill}>
                <Text style={styles.countText}>{selected.active_coupon_count}</Text>
                <Text style={styles.countLabel}>offers</Text>
              </View>
            </View>
            <TouchableOpacity style={styles.openButton} onPress={() => router.push(`/(consumer)/shop/${selected.id}`)}>
              <Text style={styles.openButtonText}>Open store</Text>
              <Ionicons name="chevron-forward" size={18} color="#fff" />
            </TouchableOpacity>
          </View>
        ) : (
          <Text style={styles.empty}>No registered shops nearby. Run backend/seed_from_osm.py before the demo.</Text>
        )}

        {shops.map((shop) => (
          <TouchableOpacity key={shop.id} style={styles.shopRow} onPress={() => setSelected(shop)}>
            <View style={[styles.busyDot, { backgroundColor: BUSYNESS_COLOR[shop.busyness] ?? "#38BDF8" }]} />
            <View style={{ flex: 1 }}>
              <Text style={styles.rowName}>{shop.name}</Text>
              <Text style={styles.rowMeta}>{shop.distance_m}m · {shop.active_coupon_count} coupons</Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color="#64748B" />
          </TouchableOpacity>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  header: { paddingHorizontal: 16, paddingTop: 12, paddingBottom: 8, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "900" },
  sub: { color: "#94A3B8", fontSize: 12, marginTop: 2 },
  refresh: { width: 38, height: 38, borderRadius: 8, backgroundColor: "#2563EB", alignItems: "center", justifyContent: "center" },
  mapPanel: { height: 300, margin: 16, borderRadius: 8, overflow: "hidden", backgroundColor: "#132033", borderWidth: 1, borderColor: "#1E3A5F" },
  map: { flex: 1 },
  mapFallback: { alignItems: "center", justifyContent: "center", padding: 20 },
  pin: { width: 42, height: 42, borderRadius: 21, borderWidth: 3, backgroundColor: "#0F172A", alignItems: "center", justifyContent: "center" },
  pinBadge: { position: "absolute", top: -8, right: -8, minWidth: 20, height: 20, borderRadius: 10, backgroundColor: "#F97316", alignItems: "center", justifyContent: "center", paddingHorizontal: 5 },
  pinBadgeText: { color: "#fff", fontSize: 11, fontWeight: "900" },
  radiusRow: { flexDirection: "row", gap: 8, paddingHorizontal: 16, paddingBottom: 10 },
  radiusChip: { paddingHorizontal: 14, paddingVertical: 6, borderRadius: 20, borderWidth: 1, borderColor: "#334155", backgroundColor: "transparent" },
  radiusChipActive: { backgroundColor: "#2563EB", borderColor: "#2563EB" },
  radiusChipText: { color: "#94A3B8", fontSize: 13, fontWeight: "700" },
  radiusChipTextActive: { color: "#fff" },
  moveBadge: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 16, paddingBottom: 8 },
  moveText: { color: "#CBD5E1", fontSize: 12, fontWeight: "700" },
  autoStatus: { color: "#86EFAC", fontWeight: "800", paddingHorizontal: 16, paddingBottom: 8 },
  sheet: { flex: 1 },
  sheetContent: { padding: 16, paddingTop: 4, paddingBottom: 30 },
  selectedCard: { padding: 16, borderRadius: 8, backgroundColor: "#1E293B", borderWidth: 1, borderColor: "#334155", marginBottom: 12 },
  sheetHead: { flexDirection: "row", alignItems: "center", gap: 12, marginBottom: 14 },
  shopName: { color: "#F8FAFC", fontSize: 19, fontWeight: "900" },
  shopMeta: { color: "#94A3B8", fontSize: 12, marginTop: 3 },
  countPill: { alignItems: "center", borderRadius: 8, borderWidth: 1, borderColor: "#334155", paddingHorizontal: 10, paddingVertical: 6 },
  countText: { color: "#F8FAFC", fontWeight: "900", fontSize: 18 },
  countLabel: { color: "#94A3B8", fontSize: 10 },
  openButton: { height: 48, borderRadius: 8, backgroundColor: "#2563EB", alignItems: "center", justifyContent: "center", flexDirection: "row", gap: 6 },
  openButtonText: { color: "#fff", fontWeight: "900" },
  shopRow: { flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: "#1E293B" },
  busyDot: { width: 10, height: 10, borderRadius: 5 },
  rowName: { color: "#E2E8F0", fontWeight: "800" },
  rowMeta: { color: "#64748B", fontSize: 12, marginTop: 2 },
  empty: { color: "#94A3B8", lineHeight: 20 },
  error: { color: "#FCA5A5", marginBottom: 8 },
});

