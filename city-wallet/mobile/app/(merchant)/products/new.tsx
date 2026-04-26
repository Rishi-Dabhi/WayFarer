import { useState } from "react";
import { View, Text, StyleSheet, TextInput, TouchableOpacity, Alert, SafeAreaView, ScrollView } from "react-native";
import { useRouter, useLocalSearchParams } from "expo-router";
import api from "@/services/api";

const CATEGORIES = ["coffee", "food", "drinks", "retail", "other"];
const STOCK_LEVELS = ["low", "normal", "high"] as const;

export default function NewProductScreen() {
  const router = useRouter();
  const { shopId } = useLocalSearchParams<{ shopId: string }>();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [price, setPrice] = useState("");
  const [category, setCategory] = useState("food");
  const [stock, setStock] = useState<"low" | "normal" | "high">("normal");
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!name || !price) { Alert.alert("Name and price are required"); return; }
    const priceCents = Math.round(parseFloat(price) * 100);
    if (isNaN(priceCents) || priceCents <= 0) { Alert.alert("Invalid price"); return; }

    setSaving(true);
    try {
      await api.post("/api/products", {
        shop_id: parseInt(shopId),
        name, description, price_cents: priceCents, category, stock_level: stock,
      });
      router.back();
    } catch {
      Alert.alert("Error", "Failed to create product");
    } finally {
      setSaving(false);
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <TouchableOpacity onPress={() => router.back()} style={styles.back}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Add Product</Text>

        <Text style={styles.label}>Name</Text>
        <TextInput style={styles.input} value={name} onChangeText={setName} placeholder="e.g. Flat White" placeholderTextColor="#64748B" />

        <Text style={styles.label}>Description</Text>
        <TextInput style={styles.input} value={description} onChangeText={setDescription} placeholder="Short description" placeholderTextColor="#64748B" />

        <Text style={styles.label}>Price (€)</Text>
        <TextInput style={styles.input} value={price} onChangeText={setPrice} keyboardType="decimal-pad" placeholder="3.80" placeholderTextColor="#64748B" />

        <Text style={styles.label}>Category</Text>
        <View style={styles.chips}>
          {CATEGORIES.map((c) => (
            <TouchableOpacity key={c} style={[styles.chip, category === c && styles.chipActive]} onPress={() => setCategory(c)}>
              <Text style={[styles.chipText, category === c && styles.chipTextActive]}>{c}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={styles.label}>Stock Level</Text>
        <View style={styles.chips}>
          {STOCK_LEVELS.map((s) => (
            <TouchableOpacity key={s} style={[styles.chip, stock === s && styles.chipActive]} onPress={() => setStock(s)}>
              <Text style={[styles.chipText, stock === s && styles.chipTextActive]}>{s}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.saveBtn} onPress={handleSave} disabled={saving}>
          <Text style={styles.saveBtnText}>{saving ? "Saving..." : "Add Product"}</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 20, paddingBottom: 40 },
  back: { marginBottom: 16 },
  backText: { color: "#3B82F6", fontSize: 14 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800", marginBottom: 24 },
  label: { color: "#94A3B8", fontSize: 12, fontWeight: "700", textTransform: "uppercase", marginBottom: 8, marginTop: 16, letterSpacing: 1 },
  input: { backgroundColor: "#1E293B", color: "#F8FAFC", padding: 14, borderRadius: 12, fontSize: 15 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, borderWidth: 1, borderColor: "#334155" },
  chipActive: { borderColor: "#F97316", backgroundColor: "#1A0D00" },
  chipText: { color: "#64748B", fontWeight: "600", fontSize: 13 },
  chipTextActive: { color: "#F97316" },
  saveBtn: { marginTop: 32, backgroundColor: "#F97316", padding: 18, borderRadius: 14, alignItems: "center" },
  saveBtnText: { color: "#fff", fontWeight: "800", fontSize: 16 },
});
