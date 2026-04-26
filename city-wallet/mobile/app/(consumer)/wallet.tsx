import { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, FlatList, TouchableOpacity, RefreshControl, SafeAreaView } from "react-native";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";
import { getUser } from "@/services/storage";

interface Coupon {
  id: number;
  headline: string;
  shop_name: string;
  discount_pct: number;
  cashback_cents: number;
  status: string;
  generated_at: string;
}

const STATUS_COLOR: Record<string, string> = {
  active: "#4ADE80",
  redeemed: "#64748B",
  expired: "#EF4444",
};

export default function WalletScreen() {
  const router = useRouter();
  const [coupons, setCoupons] = useState<Coupon[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const user = await getUser();
    if (!user?.user_id) return;
    const { data } = await api.get(`/api/coupons/user/${user.user_id}`);
    setCoupons(data);
  }, []);

  useEffect(() => { load(); }, [load]);

  const onRefresh = async () => { setRefreshing(true); await load(); setRefreshing(false); };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>My Wallet</Text>
      </View>
      <FlatList
        data={coupons}
        keyExtractor={(c) => String(c.id)}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Ionicons name="wallet-outline" size={48} color="#334155" />
            <Text style={styles.emptyText}>No offers yet — generate one from the home screen</Text>
          </View>
        }
        renderItem={({ item }) => (
          <TouchableOpacity style={styles.card} onPress={() => router.push(`/(consumer)/offer/${item.id}`)}>
            <View style={styles.cardTop}>
              <Text style={styles.cardHeadline} numberOfLines={1}>{item.headline}</Text>
              <View style={[styles.statusDot, { backgroundColor: STATUS_COLOR[item.status] ?? "#64748B" }]} />
            </View>
            <Text style={styles.cardShop}>{item.shop_name}</Text>
            <View style={styles.cardBottom}>
              <Text style={styles.cardDiscount}>{item.discount_pct}% off</Text>
              <Text style={styles.cardCashback}>€{(item.cashback_cents / 100).toFixed(2)} cashback</Text>
              <Text style={[styles.cardStatus, { color: STATUS_COLOR[item.status] }]}>{item.status}</Text>
            </View>
          </TouchableOpacity>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  header: { padding: 16 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800" },
  list: { padding: 16, gap: 12 },
  empty: { alignItems: "center", gap: 12, marginTop: 60 },
  emptyText: { color: "#475569", fontSize: 14, textAlign: "center", maxWidth: 240 },
  card: { backgroundColor: "#1E293B", borderRadius: 16, padding: 16 },
  cardTop: { flexDirection: "row", alignItems: "center", marginBottom: 4 },
  cardHeadline: { flex: 1, color: "#F8FAFC", fontWeight: "700", fontSize: 15 },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  cardShop: { color: "#64748B", fontSize: 12, marginBottom: 10 },
  cardBottom: { flexDirection: "row", alignItems: "center", gap: 10 },
  cardDiscount: { color: "#F97316", fontSize: 12, fontWeight: "600" },
  cardCashback: { color: "#4ADE80", fontSize: 12, fontWeight: "600", flex: 1 },
  cardStatus: { fontSize: 11, fontWeight: "700", textTransform: "uppercase" },
});
