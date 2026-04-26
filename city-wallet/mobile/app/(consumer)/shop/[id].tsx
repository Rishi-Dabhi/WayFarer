import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useLocalSearchParams, useRouter } from "expo-router";
import api from "@/services/api";

export default function ShopDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [detail, setDetail] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try {
      const { data } = await api.get(`/api/shops/${id}`);
      setDetail(data);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [id]);

  if (loading || !detail) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator color="#38BDF8" style={{ marginTop: 80 }} />
      </SafeAreaView>
    );
  }

  const shop = detail.shop;

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <TouchableOpacity style={styles.back} onPress={() => router.back()}>
          <Ionicons name="arrow-back" size={20} color="#CBD5E1" />
          <Text style={styles.backText}>Map</Text>
        </TouchableOpacity>

        <View style={styles.hero}>
          <View style={styles.iconCircle}>
            <Ionicons name="storefront" size={24} color="#F8FAFC" />
          </View>
          <Text style={styles.name}>{shop.name}</Text>
          <Text style={styles.meta}>{shop.category} · {shop.address}</Text>
          <View style={styles.pills}>
            <Text style={styles.pill}>{detail.busyness.busyness ?? detail.busyness.level}</Text>
            <Text style={styles.pill}>{detail.active_coupons?.length ?? 0} coupons</Text>
          </View>
        </View>

        <Section title="Available coupons">
          {detail.active_coupons.length === 0 ? (
            <Text style={styles.empty}>No live coupons yet. Offers appear automatically when the merchant's rules match the live context.</Text>
          ) : (
            detail.active_coupons.map((coupon: any) => (
              <TouchableOpacity key={coupon.id} style={styles.couponCard} onPress={() => router.push(`/(consumer)/offer/${coupon.id}`)}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.couponTitle}>{coupon.headline}</Text>
                  <Text style={styles.couponBody} numberOfLines={2}>{coupon.body_text}</Text>
                </View>
                <View style={styles.cashback}>
                  <Text style={styles.cashbackValue}>EUR {(coupon.cashback_cents / 100).toFixed(2)}</Text>
                  <Text style={styles.cashbackLabel}>cashback</Text>
                </View>
              </TouchableOpacity>
            ))
          )}
        </Section>

        <Section title="Products">
          {detail.products.map((product: any) => (
            <View key={product.id} style={styles.productRow}>
              <View>
                <Text style={styles.productName}>{product.name}</Text>
                <Text style={styles.productMeta}>{product.stock_level} stock</Text>
              </View>
              <Text style={styles.price}>EUR {(product.price_cents / 100).toFixed(2)}</Text>
            </View>
          ))}
        </Section>
      </ScrollView>
    </SafeAreaView>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  content: { padding: 16, paddingBottom: 40 },
  back: { flexDirection: "row", alignItems: "center", gap: 6, marginBottom: 16 },
  backText: { color: "#CBD5E1", fontWeight: "700" },
  hero: { paddingVertical: 10, marginBottom: 24 },
  iconCircle: { width: 52, height: 52, borderRadius: 26, backgroundColor: "#2563EB", alignItems: "center", justifyContent: "center", marginBottom: 14 },
  name: { color: "#F8FAFC", fontSize: 30, fontWeight: "900", lineHeight: 35 },
  meta: { color: "#94A3B8", marginTop: 6, lineHeight: 20 },
  pills: { flexDirection: "row", gap: 8, marginTop: 14 },
  pill: { color: "#BAE6FD", borderColor: "#075985", borderWidth: 1, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5, overflow: "hidden" },
  section: { marginBottom: 24 },
  sectionTitle: { color: "#F8FAFC", fontSize: 17, fontWeight: "800", marginBottom: 10 },
  empty: { color: "#94A3B8", lineHeight: 20 },
  couponCard: { flexDirection: "row", gap: 12, padding: 14, borderRadius: 8, backgroundColor: "#1E293B", marginBottom: 10 },
  couponTitle: { color: "#F8FAFC", fontSize: 16, fontWeight: "800" },
  couponBody: { color: "#94A3B8", fontSize: 12, marginTop: 4, lineHeight: 17 },
  cashback: { alignItems: "flex-end", justifyContent: "center" },
  cashbackValue: { color: "#86EFAC", fontWeight: "900" },
  cashbackLabel: { color: "#94A3B8", fontSize: 10 },
  productRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: "#1E293B" },
  productName: { color: "#E2E8F0", fontWeight: "700" },
  productMeta: { color: "#64748B", fontSize: 12, marginTop: 2 },
  price: { color: "#F8FAFC", fontWeight: "800" },
});
