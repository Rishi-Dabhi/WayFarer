import { useEffect, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Modal } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useLocalSearchParams, useRouter } from "expo-router";
import QRCode from "react-native-qrcode-svg";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";

interface Coupon {
  id: number;
  headline: string;
  body_text: string;
  why_now: string;
  discount_pct: number;
  cashback_cents: number;
  qr_token: string;
  shop_name: string;
  address: string;
  expires_at: string;
  status: string;
  context_snapshot?: string;
}

export default function OfferDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [coupon, setCoupon] = useState<Coupon | null>(null);
  const [whyOpen, setWhyOpen] = useState(false);
  const [qrOpen, setQrOpen] = useState(false);

  useEffect(() => {
    api.get(`/api/coupons/${id}`).then(({ data }) => setCoupon(data)).catch(() => {});
  }, [id]);

  if (!coupon) {
    return <SafeAreaView style={styles.container} />;
  }

  const isRedeemed = coupon.status === "redeemed";
  const expires = new Date(coupon.expires_at + "Z");
  const expiresStr = expires.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <TouchableOpacity style={styles.back} onPress={() => router.back()}>
          <Ionicons name="arrow-back" size={20} color="#94A3B8" />
          <Text style={styles.backText}>Back</Text>
        </TouchableOpacity>

        <Text style={styles.shop}>{coupon.shop_name} · {coupon.address}</Text>
        <Text style={styles.headline}>{coupon.headline}</Text>

        <View style={styles.statsRow}>
          <View style={styles.stat}>
            <Text style={styles.statVal}>{coupon.discount_pct}%</Text>
            <Text style={styles.statLabel}>Discount</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.stat}>
            <Text style={[styles.statVal, { color: "#4ADE80" }]}>EUR {(coupon.cashback_cents / 100).toFixed(2)}</Text>
            <Text style={styles.statLabel}>Cashback</Text>
          </View>
        </View>

        <Text style={styles.body}>{coupon.body_text}</Text>

        {!isRedeemed ? (
          <TouchableOpacity style={styles.qrButton} onPress={() => setQrOpen(true)}>
            <Ionicons name="qr-code" size={18} color="#fff" />
            <Text style={styles.qrButtonText}>View QR code</Text>
          </TouchableOpacity>
        ) : (
          <View style={styles.redeemed}>
            <Ionicons name="checkmark-circle" size={22} color="#4ADE80" />
            <Text style={styles.redeemedText}>Redeemed</Text>
          </View>
        )}

        {!isRedeemed && <Text style={styles.expiry}>Expires at {expiresStr}</Text>}

        <TouchableOpacity style={styles.whyRow} onPress={() => setWhyOpen(!whyOpen)}>
          <Ionicons name="information-circle-outline" size={16} color="#64748B" />
          <Text style={styles.whyLabel}>Why this offer?</Text>
          <Ionicons name={whyOpen ? "chevron-up" : "chevron-down"} size={14} color="#64748B" />
        </TouchableOpacity>
        {whyOpen && <Text style={styles.whyText}>{coupon.why_now}</Text>}
      </ScrollView>

      <Modal visible={qrOpen} transparent animationType="fade" onRequestClose={() => setQrOpen(false)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.qrModal}>
            <Text style={styles.qrTitle}>{coupon.headline}</Text>
            <View style={styles.qrBox}>
              <QRCode value={coupon.qr_token} size={230} backgroundColor="#fff" color="#0F172A" />
            </View>
            <TouchableOpacity style={styles.closeButton} onPress={() => setQrOpen(false)}>
              <Text style={styles.closeText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 20, paddingBottom: 40 },
  back: { flexDirection: "row", alignItems: "center", gap: 6, marginBottom: 20 },
  backText: { color: "#94A3B8", fontSize: 14 },
  headline: { color: "#F8FAFC", fontSize: 30, fontWeight: "900", lineHeight: 36, marginBottom: 18 },
  shop: { color: "#94A3B8", fontSize: 13, marginBottom: 8 },
  statsRow: { flexDirection: "row", backgroundColor: "#1E293B", borderRadius: 8, marginBottom: 20, overflow: "hidden" },
  stat: { flex: 1, padding: 16, alignItems: "center" },
  statVal: { color: "#F8FAFC", fontSize: 22, fontWeight: "900" },
  statLabel: { color: "#64748B", fontSize: 11, marginTop: 2 },
  statDivider: { width: 1, backgroundColor: "#334155" },
  body: { color: "#CBD5E1", fontSize: 15, lineHeight: 23, marginBottom: 24 },
  qrButton: { height: 52, borderRadius: 8, backgroundColor: "#2563EB", flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8 },
  qrButtonText: { color: "#fff", fontWeight: "900" },
  redeemed: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, backgroundColor: "#0D1F0D", borderRadius: 8, padding: 14 },
  redeemedText: { color: "#4ADE80", fontWeight: "900" },
  expiry: { color: "#64748B", fontSize: 12, textAlign: "center", marginTop: 10, marginBottom: 20 },
  whyRow: { flexDirection: "row", alignItems: "center", gap: 6, padding: 14, backgroundColor: "#1E293B", borderRadius: 8, marginBottom: 8 },
  whyLabel: { flex: 1, color: "#94A3B8", fontSize: 13 },
  whyText: { color: "#94A3B8", fontSize: 13, lineHeight: 20, padding: 14, backgroundColor: "#0F1D2E", borderRadius: 8 },
  modalBackdrop: { flex: 1, backgroundColor: "rgba(2, 6, 23, 0.86)", alignItems: "center", justifyContent: "center", padding: 22 },
  qrModal: { width: "100%", maxWidth: 360, borderRadius: 8, backgroundColor: "#F8FAFC", padding: 20, alignItems: "center" },
  qrTitle: { color: "#0F172A", fontSize: 18, fontWeight: "900", textAlign: "center", marginBottom: 16 },
  qrBox: { padding: 16, backgroundColor: "#fff", borderRadius: 8 },
  closeButton: { marginTop: 18, height: 44, alignSelf: "stretch", backgroundColor: "#0F172A", borderRadius: 8, alignItems: "center", justifyContent: "center" },
  closeText: { color: "#fff", fontWeight: "900" },
});

