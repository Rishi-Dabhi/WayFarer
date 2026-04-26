import { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Alert, SafeAreaView, RefreshControl } from "react-native";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";
import { getUser } from "@/services/storage";

interface Product {
  id: number;
  name: string;
  description: string;
  price_cents: number;
  category: string;
  stock_level: string;
}

const STOCK_COLOR: Record<string, string> = {
  low: "#EF4444",
  normal: "#4ADE80",
  high: "#60A5FA",
};

export default function ProductsScreen() {
  const router = useRouter();
  const [products, setProducts] = useState<Product[]>([]);
  const [shopId, setShopId] = useState<number | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const user = await getUser();
    if (!user) return;
    const { data: shops } = await api.get(`/api/merchants/shop/${user.user_id}`);
    if (shops.length === 0) return;
    setShopId(shops[0].id);
    const { data } = await api.get(`/api/products?shop_id=${shops[0].id}`);
    setProducts(data);
  }, []);

  useEffect(() => { load(); }, [load]);

  const onRefresh = async () => { setRefreshing(true); await load(); setRefreshing(false); };

  async function handleDelete(id: number) {
    Alert.alert("Remove product?", "", [
      { text: "Cancel" },
      {
        text: "Remove",
        style: "destructive",
        onPress: async () => {
          await api.delete(`/api/products/${id}`);
          await load();
        },
      },
    ]);
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Products</Text>
        <TouchableOpacity
          style={styles.addBtn}
          onPress={() => router.push({ pathname: "/(merchant)/products/new", params: { shopId: String(shopId) } })}
        >
          <Ionicons name="add" size={20} color="#fff" />
        </TouchableOpacity>
      </View>
      <FlatList
        data={products}
        keyExtractor={(p) => String(p.id)}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#F97316" />}
        contentContainerStyle={styles.list}
        ListEmptyComponent={<Text style={styles.empty}>No products yet — tap + to add one</Text>}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <View style={styles.cardTop}>
              <View style={styles.cardInfo}>
                <Text style={styles.cardName}>{item.name}</Text>
                <Text style={styles.cardDesc} numberOfLines={1}>{item.description}</Text>
              </View>
              <TouchableOpacity onPress={() => handleDelete(item.id)} style={styles.deleteBtn}>
                <Ionicons name="trash-outline" size={16} color="#64748B" />
              </TouchableOpacity>
            </View>
            <View style={styles.cardBottom}>
              <Text style={styles.cardPrice}>€{(item.price_cents / 100).toFixed(2)}</Text>
              <Text style={styles.cardCategory}>{item.category}</Text>
              <View style={[styles.stockBadge, { backgroundColor: STOCK_COLOR[item.stock_level] + "20" }]}>
                <Text style={[styles.stockText, { color: STOCK_COLOR[item.stock_level] }]}>{item.stock_level}</Text>
              </View>
            </View>
          </View>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  header: { flexDirection: "row", alignItems: "center", padding: 16 },
  title: { flex: 1, color: "#F8FAFC", fontSize: 24, fontWeight: "800" },
  addBtn: { backgroundColor: "#F97316", width: 36, height: 36, borderRadius: 18, justifyContent: "center", alignItems: "center" },
  list: { padding: 16, gap: 10 },
  empty: { color: "#475569", fontSize: 14, textAlign: "center", marginTop: 40 },
  card: { backgroundColor: "#1E293B", borderRadius: 14, padding: 14 },
  cardTop: { flexDirection: "row", alignItems: "flex-start", marginBottom: 10 },
  cardInfo: { flex: 1 },
  cardName: { color: "#F8FAFC", fontWeight: "700", fontSize: 15 },
  cardDesc: { color: "#64748B", fontSize: 12, marginTop: 2 },
  deleteBtn: { padding: 4 },
  cardBottom: { flexDirection: "row", alignItems: "center", gap: 10 },
  cardPrice: { color: "#F8FAFC", fontWeight: "700", fontSize: 14 },
  cardCategory: { color: "#64748B", fontSize: 12, flex: 1 },
  stockBadge: { paddingHorizontal: 8, paddingVertical: 3, borderRadius: 8 },
  stockText: { fontSize: 11, fontWeight: "700", textTransform: "uppercase" },
});
