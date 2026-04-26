import { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, TouchableOpacity, TextInput, Alert, ScrollView, SafeAreaView, RefreshControl } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";
import { getUser } from "@/services/storage";

interface WalletData {
  balance_cents: number;
  updated_at: string;
  topup_history: Array<{ amount_cents: number; status: string; created_at: string }>;
}

export default function MerchantWallet() {
  const [wallet, setWallet] = useState<WalletData | null>(null);
  const [merchantId, setMerchantId] = useState<number | null>(null);
  const [topupAmount, setTopupAmount] = useState("20");
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const user = await getUser();
    if (!user?.user_id) return;
    const mid = Number(user.user_id);
    setMerchantId(mid);
    const { data } = await api.get(`/api/wallet/balance/${mid}`);
    setWallet(data);
  }, []);

  useEffect(() => { load(); }, [load]);

  const onRefresh = async () => { setRefreshing(true); await load(); setRefreshing(false); };

  async function handleTopUp() {
    if (!merchantId) return;
    const euros = parseFloat(topupAmount);
    if (isNaN(euros) || euros < 1) { Alert.alert("Minimum top-up is €1.00"); return; }

    setLoading(true);
    try {
      const { data } = await api.post("/api/wallet/topup", {
        merchant_id: merchantId,
        amount_cents: Math.round(euros * 100),
      });

      await api.post("/api/wallet/topup/confirm", { payment_intent_id: data.payment_intent_id });
      Alert.alert(
        "Demo wallet topped up",
        `EUR ${euros.toFixed(2)} was added through the Expo Go demo path.`
      );
      await load();
    } catch {
      Alert.alert("Error", "Top-up failed. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#F97316" />}
      >
        <Text style={styles.title}>Organisation Wallet</Text>

        {wallet && (
          <View style={styles.balanceCard}>
            <Ionicons name="wallet" size={28} color="#F97316" />
            <Text style={styles.balanceLabel}>Available Balance</Text>
            <Text style={styles.balanceVal}>€{(wallet.balance_cents / 100).toFixed(2)}</Text>
            <Text style={styles.balanceSub}>Used for cashback payouts to customers</Text>
          </View>
        )}

        <Text style={styles.sectionTitle}>Top Up Wallet</Text>
        <View style={styles.topupCard}>
          <Text style={styles.topupLabel}>Amount (€)</Text>
          <View style={styles.topupRow}>
            <TextInput
              style={styles.topupInput}
              value={topupAmount}
              onChangeText={setTopupAmount}
              keyboardType="decimal-pad"
              placeholder="20"
              placeholderTextColor="#64748B"
            />
            <TouchableOpacity style={styles.topupBtn} onPress={handleTopUp} disabled={loading}>
              <Text style={styles.topupBtnText}>{loading ? "Processing..." : "Add Funds"}</Text>
            </TouchableOpacity>
          </View>
          <Text style={styles.topupNote}>
            Expo Go demo mode credits wallet through the backend fallback.
          </Text>
        </View>

        {wallet && wallet.topup_history.length > 0 && (
          <>
            <Text style={styles.sectionTitle}>Top-up History</Text>
            {wallet.topup_history.map((t, i) => (
              <View key={i} style={styles.histRow}>
                <View>
                  <Text style={styles.histAmount}>+€{(t.amount_cents / 100).toFixed(2)}</Text>
                  <Text style={styles.histDate}>{new Date(t.created_at).toLocaleDateString()}</Text>
                </View>
                <Text style={[styles.histStatus, t.status === "succeeded" ? styles.green : styles.pending]}>
                  {t.status}
                </Text>
              </View>
            ))}
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 16 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800", marginBottom: 20 },
  balanceCard: { backgroundColor: "#1A0D00", borderRadius: 20, padding: 24, alignItems: "center", gap: 8, marginBottom: 24, borderWidth: 1, borderColor: "#F97316" },
  balanceLabel: { color: "#94A3B8", fontSize: 13 },
  balanceVal: { color: "#F8FAFC", fontSize: 40, fontWeight: "800" },
  balanceSub: { color: "#64748B", fontSize: 12, textAlign: "center" },
  sectionTitle: { color: "#94A3B8", fontSize: 12, fontWeight: "700", textTransform: "uppercase", marginBottom: 12, letterSpacing: 1 },
  topupCard: { backgroundColor: "#1E293B", borderRadius: 16, padding: 16, marginBottom: 24 },
  topupLabel: { color: "#94A3B8", fontSize: 12, marginBottom: 10 },
  topupRow: { flexDirection: "row", gap: 10 },
  topupInput: { flex: 1, backgroundColor: "#0F172A", color: "#F8FAFC", padding: 14, borderRadius: 10, fontSize: 16 },
  topupBtn: { backgroundColor: "#F97316", paddingHorizontal: 20, borderRadius: 10, justifyContent: "center" },
  topupBtnText: { color: "#fff", fontWeight: "700" },
  topupNote: { color: "#475569", fontSize: 11, marginTop: 10 },
  histRow: { flexDirection: "row", alignItems: "center", backgroundColor: "#1E293B", borderRadius: 12, padding: 14, marginBottom: 8 },
  histAmount: { color: "#4ADE80", fontWeight: "700", fontSize: 16, flex: 1 },
  histDate: { color: "#64748B", fontSize: 11 },
  histStatus: { fontSize: 12, fontWeight: "600", textTransform: "uppercase" },
  green: { color: "#4ADE80" },
  pending: { color: "#F59E0B" },
});
