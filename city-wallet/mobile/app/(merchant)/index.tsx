import { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, ScrollView, RefreshControl, TouchableOpacity, SafeAreaView, TextInput, Alert } from "react-native";
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
  unique_visitors_last_14_days: number;
  recent_redemptions: Array<{ headline: string; cashback_cents: number; redeemed_at: string; discount_pct: number }>;
}

export default function MerchantDashboard() {
  const router = useRouter();
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [hasShop, setHasShop] = useState<boolean | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [submittingSetup, setSubmittingSetup] = useState(false);
  const [shopName, setShopName] = useState("");
  const [shopDescription, setShopDescription] = useState("");
  const [shopCategory, setShopCategory] = useState("retail");
  const [shopAddress, setShopAddress] = useState("");
  const [shopLat, setShopLat] = useState("");
  const [shopLng, setShopLng] = useState("");
  const [maxDiscountPct, setMaxDiscountPct] = useState("15");
  const [productName, setProductName] = useState("");
  const [productDescription, setProductDescription] = useState("");
  const [productPrice, setProductPrice] = useState("");

  const load = useCallback(async () => {
    const user = await getUser();
    if (!user) return;
    const mid = Number(user.user_id);
    const { data: shops } = await api.get(`/api/merchants/shop/${mid}`);
    if (shops.length === 0) {
      setHasShop(false);
      setAnalytics(null);
      return;
    }
    setHasShop(true);
    const sid = shops[0].id;
    const { data } = await api.get(`/api/analytics/merchant/${sid}`);
    setAnalytics(data);
  }, []);

  useEffect(() => { load(); }, [load]);

  const onRefresh = async () => { setRefreshing(true); await load(); setRefreshing(false); };

  async function handleCreateStore() {
    if (!shopName || !shopLat || !shopLng || !productName || !productPrice) {
      Alert.alert("Missing fields", "Store name, lat/lng, first product name and price are required.");
      return;
    }

    const lat = Number(shopLat);
    const lng = Number(shopLng);
    const discount = Number(maxDiscountPct);
    const priceCents = Math.round(Number(productPrice) * 100);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      Alert.alert("Invalid location", "Please enter valid latitude and longitude.");
      return;
    }
    if (!Number.isFinite(discount) || discount < 1 || discount > 100) {
      Alert.alert("Invalid discount", "Discount percentage must be between 1 and 100.");
      return;
    }
    if (!Number.isFinite(priceCents) || priceCents <= 0) {
      Alert.alert("Invalid product price", "Please enter a valid price above 0.");
      return;
    }

    setSubmittingSetup(true);
    try {
      const { data: shop } = await api.post("/api/merchants/shop", {
        name: shopName,
        description: shopDescription,
        category: shopCategory,
        latitude: lat,
        longitude: lng,
        address: shopAddress,
        max_discount_pct: discount,
      });

      await api.post("/api/products", {
        shop_id: shop.id,
        name: productName,
        description: productDescription,
        price_cents: priceCents,
        category: "other",
        stock_level: "normal",
      });

      await load();
      Alert.alert("Store created", "Your store, product, and campaign discount are now active.");
    } catch {
      Alert.alert("Setup failed", "Could not create your store. Please check your values and try again.");
    } finally {
      setSubmittingSetup(false);
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#F97316" />}
      >
        <Text style={styles.title}>Dashboard</Text>

        {hasShop === false ? (
          <View style={styles.setupCard}>
            <Text style={styles.setupTitle}>Add your store</Text>
            <Text style={styles.setupSub}>Your info and products here are used to build live promotional deals later.</Text>

            <Text style={styles.label}>Store Name</Text>
            <TextInput style={styles.input} value={shopName} onChangeText={setShopName} placeholder="e.g. City Beans" placeholderTextColor="#64748B" />

            <Text style={styles.label}>Store Description</Text>
            <TextInput style={styles.input} value={shopDescription} onChangeText={setShopDescription} placeholder="What makes your shop special?" placeholderTextColor="#64748B" />

            <Text style={styles.label}>Category</Text>
            <TextInput style={styles.input} value={shopCategory} onChangeText={setShopCategory} placeholder="retail, cafe, food..." placeholderTextColor="#64748B" />

            <Text style={styles.label}>Address</Text>
            <TextInput style={styles.input} value={shopAddress} onChangeText={setShopAddress} placeholder="Street and city" placeholderTextColor="#64748B" />

            <View style={styles.row}>
              <View style={{ flex: 1 }}>
                <Text style={styles.label}>Latitude</Text>
                <TextInput style={styles.input} value={shopLat} onChangeText={setShopLat} keyboardType="decimal-pad" placeholder="48.7784" placeholderTextColor="#64748B" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.label}>Longitude</Text>
                <TextInput style={styles.input} value={shopLng} onChangeText={setShopLng} keyboardType="decimal-pad" placeholder="9.1800" placeholderTextColor="#64748B" />
              </View>
            </View>

            <Text style={styles.label}>Max Discount %</Text>
            <TextInput style={styles.input} value={maxDiscountPct} onChangeText={setMaxDiscountPct} keyboardType="numeric" placeholder="15" placeholderTextColor="#64748B" />

            <Text style={styles.setupTitle}>First Product</Text>
            <Text style={styles.label}>Product Name</Text>
            <TextInput style={styles.input} value={productName} onChangeText={setProductName} placeholder="e.g. Cappuccino" placeholderTextColor="#64748B" />

            <Text style={styles.label}>Product Description</Text>
            <TextInput style={styles.input} value={productDescription} onChangeText={setProductDescription} placeholder="Short product details" placeholderTextColor="#64748B" />

            <Text style={styles.label}>Product Price (€)</Text>
            <TextInput style={styles.input} value={productPrice} onChangeText={setProductPrice} keyboardType="decimal-pad" placeholder="3.50" placeholderTextColor="#64748B" />

            <TouchableOpacity style={styles.primaryBtn} onPress={handleCreateStore} disabled={submittingSetup}>
              <Text style={styles.primaryBtnText}>{submittingSetup ? "Creating..." : "Create Store"}</Text>
            </TouchableOpacity>
          </View>
        ) : analytics ? (
          <>
            <View style={styles.metricsRow}>
              <MetricCard label="Generated Today" value={analytics.coupons_generated_today} icon="flash" color="#3B82F6" />
              <MetricCard label="Redeemed Today" value={analytics.redemptions_today} icon="checkmark-circle" color="#4ADE80" />
            </View>
            <View style={styles.metricsRow}>
              <MetricCard label="Visitors (14d)" value={analytics.unique_visitors_last_14_days} icon="people" color="#F97316" />
              <MetricCard label="Spent Today" value={`€${(analytics.wallet_spent_today_cents / 100).toFixed(2)}`} icon="wallet" color="#A855F7" />
            </View>
            <View style={styles.metricsRow}>
              <MetricCard label="Redemption Rate" value={`${analytics.redemption_rate_pct}%`} icon="trending-up" color="#22C55E" />
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

        {hasShop && (
          <TouchableOpacity style={styles.analyticsBtn} onPress={() => router.push("/(merchant)/analytics")}>
            <Text style={styles.analyticsBtnText}>View Full Analytics →</Text>
          </TouchableOpacity>
        )}
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
  setupCard: { backgroundColor: "#1E293B", borderRadius: 14, padding: 14, borderWidth: 1, borderColor: "#334155" },
  setupTitle: { color: "#F8FAFC", fontSize: 18, fontWeight: "800", marginTop: 12, marginBottom: 8 },
  setupSub: { color: "#94A3B8", fontSize: 12, lineHeight: 18, marginBottom: 8 },
  label: { color: "#94A3B8", fontSize: 11, textTransform: "uppercase", marginTop: 12, marginBottom: 6, fontWeight: "700" },
  input: { backgroundColor: "#0F172A", borderWidth: 1, borderColor: "#334155", color: "#F8FAFC", padding: 12, borderRadius: 10 },
  row: { flexDirection: "row", gap: 10 },
  primaryBtn: { marginTop: 18, backgroundColor: "#F97316", borderRadius: 12, padding: 14, alignItems: "center" },
  primaryBtnText: { color: "#fff", fontWeight: "800" },
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
