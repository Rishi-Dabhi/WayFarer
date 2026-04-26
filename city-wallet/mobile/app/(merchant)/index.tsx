import { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, ScrollView, RefreshControl, TouchableOpacity, SafeAreaView } from "react-native";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";
import { getUser } from "@/services/storage";

interface Analytics {
  coupons_generated_today: number;
  redemptions_today: number;
  redemption_rate_pct: number;
  avg_discount_pct: number;
  wallet_spent_today_cents: number;
  recent_redemptions: Array<{ headline: string; cashback_cents: number; redeemed_at: string; discount_pct: number }>;
}

export default function MerchantDashboard() {
  const router = useRouter();
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [shopId, setShopId] = useState<number | null>(null);
  const [merchantId, setMerchantId] = useState<number | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const user = await getUser();
    if (!user) return;
    const mid = Number(user.user_id);
    setMerchantId(mid);
    const { data: shops } = await api.get(`/api/merchants/shop/${mid}`);
    if (shops.length === 0) return;
    const sid = shops[0].id;
    setShopId(sid);
    const { data } = await api.get(`/api/analytics/merchant/${sid}`);
    setAnalytics(data);
  }, []);

  useEffect(() => { load(); }, [load]);

  const onRefresh = async () => { setRefreshing(true); await load(); setRefreshing(false); };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#F97316" />}
      >
        <Text style={styles.title}>Dashboard</Text>

        {analytics ? (
          <>
            <View style={styles.metricsRow}>
              <MetricCard label="Generated Today" value={analytics.coupons_generated_today} icon="flash" color="#3B82F6" />
              <MetricCard label="Redeemed Today" value={analytics.redemptions_today} icon="checkmark-circle" color="#4ADE80" />
            </View>
            <View style={styles.metricsRow}>
              <MetricCard label="Redemption Rate" value={`${analytics.redemption_rate_pct}%`} icon="trending-up" color="#F97316" />
              <MetricCard label="Spent Today" value={`€${(analytics.wallet_spent_today_cents / 100).toFixed(2)}`} icon="wallet" color="#A855F7" />
            </View>

            <Text style={styles.sectionTitle}>Recent Redemptions</Text>
            {analytics.recent_redemptions.length === 0 ? (
              <Text style={styles.empty}>No redemptions yet today</Text>
            ) : (
              analytics.recent_redemptions.map((r, i) => (
                <View key={i} style={styles.redemptionRow}>
                  <View style={styles.redemptionInfo}>
                    <Text style={styles.redemptionHeadline} numberOfLines={1}>{r.headline}</Text>
                    <Text style={styles.redemptionTime}>{new Date(r.redeemed_at + "Z").toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</Text>
                  </View>
                  <Text style={styles.redemptionCashback}>-€{(r.cashback_cents / 100).toFixed(2)}</Text>
                </View>
              ))
            )}
          </>
        ) : (
          <Text style={styles.empty}>Loading analytics...</Text>
        )}

        <TouchableOpacity style={styles.analyticsBtn} onPress={() => router.push("/(merchant)/analytics")}>
          <Text style={styles.analyticsBtnText}>View Full Analytics →</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

function MetricCard({ label, value, icon, color }: { label: string; value: number | string; icon: string; color: string }) {
  return (
    <View style={[styles.metricCard, { borderColor: color }]}>
      <Ionicons name={icon as never} size={20} color={color} />
      <Text style={[styles.metricVal, { color }]}>{value}</Text>
      <Text style={styles.metricLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 16 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800", marginBottom: 20 },
  metricsRow: { flexDirection: "row", gap: 12, marginBottom: 12 },
  metricCard: { flex: 1, backgroundColor: "#1E293B", borderRadius: 16, padding: 14, borderWidth: 1, gap: 6 },
  metricVal: { fontSize: 26, fontWeight: "800" },
  metricLabel: { color: "#64748B", fontSize: 11 },
  sectionTitle: { color: "#94A3B8", fontSize: 12, fontWeight: "700", textTransform: "uppercase", marginTop: 20, marginBottom: 12, letterSpacing: 1 },
  redemptionRow: { flexDirection: "row", alignItems: "center", backgroundColor: "#1E293B", borderRadius: 12, padding: 12, marginBottom: 8 },
  redemptionInfo: { flex: 1 },
  redemptionHeadline: { color: "#F8FAFC", fontSize: 13, fontWeight: "600" },
  redemptionTime: { color: "#64748B", fontSize: 11, marginTop: 2 },
  redemptionCashback: { color: "#EF4444", fontWeight: "700", fontSize: 14 },
  empty: { color: "#475569", fontSize: 14, textAlign: "center", marginTop: 20 },
  analyticsBtn: { marginTop: 20, padding: 14, borderRadius: 12, borderWidth: 1, borderColor: "#334155", alignItems: "center" },
  analyticsBtnText: { color: "#64748B", fontSize: 14 },
});
