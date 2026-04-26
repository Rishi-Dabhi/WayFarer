import { useState, useEffect } from "react";
import { View, Text, StyleSheet, TouchableOpacity, Alert, SafeAreaView } from "react-native";
import { CameraView, useCameraPermissions } from "expo-camera";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";
import { getUser } from "@/services/storage";

interface ValidatedCoupon {
  headline: string;
  body_text: string;
  discount_pct: number;
  cashback_cents: number;
  shop_name: string;
  qr_token: string;
  status: string;
}

export default function ScanScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [coupon, setCoupon] = useState<ValidatedCoupon | null>(null);
  const [redeeming, setRedeeming] = useState(false);
  const [success, setSuccess] = useState(false);
  const [merchantId, setMerchantId] = useState<number | null>(null);

  useEffect(() => {
    getUser().then((u) => u?.user_id && setMerchantId(Number(u.user_id)));
  }, []);

  async function handleBarcode({ data }: { data: string }) {
    if (scanned) return;
    setScanned(true);

    // Extract token from QR data (can be full URL or raw token)
    const token = data.includes("/") ? data.split("/").pop()! : data;

    try {
      const { data: couponData } = await api.get(`/api/coupons/validate/${token}`);
      setCoupon(couponData);
    } catch (e: unknown) {
      const detail = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? "Invalid or expired coupon";
      Alert.alert("Invalid QR", detail, [{ text: "Scan again", onPress: reset }]);
    }
  }

  async function handleRedeem() {
    if (!coupon || !merchantId) return;
    setRedeeming(true);
    try {
      await api.post("/api/coupons/redeem", { token: coupon.qr_token, merchant_id: merchantId });
      setSuccess(true);
    } catch (e: unknown) {
      const detail = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? "Redemption failed";
      Alert.alert("Error", detail);
    } finally {
      setRedeeming(false);
    }
  }

  function reset() {
    setScanned(false);
    setCoupon(null);
    setSuccess(false);
  }

  if (!permission) return <View style={styles.container} />;
  if (!permission.granted) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.center}>
          <Text style={styles.permText}>Camera access needed to scan QR codes</Text>
          <TouchableOpacity style={styles.btn} onPress={requestPermission}>
            <Text style={styles.btnText}>Grant Permission</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  if (success) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.center}>
          <Ionicons name="checkmark-circle" size={80} color="#4ADE80" />
          <Text style={styles.successTitle}>Redeemed!</Text>
          <Text style={styles.successSub}>
            €{(coupon!.cashback_cents / 100).toFixed(2)} cashback sent to customer
          </Text>
          <TouchableOpacity style={[styles.btn, { marginTop: 24 }]} onPress={reset}>
            <Text style={styles.btnText}>Scan Another</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  if (coupon) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.couponBox}>
          <Text style={styles.couponHeadline}>{coupon.headline}</Text>
          <Text style={styles.couponShop}>{coupon.shop_name}</Text>
          <View style={styles.couponStats}>
            <View style={styles.couponStat}>
              <Text style={styles.couponStatVal}>{coupon.discount_pct}%</Text>
              <Text style={styles.couponStatLabel}>Discount</Text>
            </View>
            <View style={styles.couponStat}>
              <Text style={[styles.couponStatVal, { color: "#4ADE80" }]}>
                €{(coupon.cashback_cents / 100).toFixed(2)}
              </Text>
              <Text style={styles.couponStatLabel}>Cashback</Text>
            </View>
          </View>
          <Text style={styles.couponBody} numberOfLines={2}>{coupon.body_text}</Text>

          <TouchableOpacity style={styles.confirmBtn} onPress={handleRedeem} disabled={redeeming}>
            <Text style={styles.confirmBtnText}>{redeeming ? "Processing..." : "Confirm Redemption"}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.cancelBtn} onPress={reset}>
            <Text style={styles.cancelBtnText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <CameraView
        style={{ flex: 1 }}
        barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
        onBarcodeScanned={scanned ? undefined : handleBarcode}
      />
      <View style={styles.overlay}>
        <View style={styles.scanFrame} />
        <Text style={styles.scanHint}>Point camera at customer's QR code</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  center: { flex: 1, justifyContent: "center", alignItems: "center", padding: 24, gap: 12 },
  permText: { color: "#94A3B8", fontSize: 15, textAlign: "center" },
  overlay: { ...StyleSheet.absoluteFillObject, justifyContent: "center", alignItems: "center" },
  scanFrame: { width: 240, height: 240, borderWidth: 2, borderColor: "#F97316", borderRadius: 16 },
  scanHint: { color: "#fff", marginTop: 20, fontSize: 13, backgroundColor: "rgba(0,0,0,0.6)", padding: 8, borderRadius: 8 },
  couponBox: { flex: 1, padding: 24, justifyContent: "center" },
  couponHeadline: { color: "#F8FAFC", fontSize: 26, fontWeight: "800", marginBottom: 4 },
  couponShop: { color: "#64748B", fontSize: 13, marginBottom: 24 },
  couponStats: { flexDirection: "row", backgroundColor: "#1E293B", borderRadius: 16, marginBottom: 16, overflow: "hidden" },
  couponStat: { flex: 1, padding: 16, alignItems: "center" },
  couponStatVal: { color: "#F8FAFC", fontSize: 24, fontWeight: "800" },
  couponStatLabel: { color: "#64748B", fontSize: 11 },
  couponBody: { color: "#94A3B8", fontSize: 13, lineHeight: 20, marginBottom: 32 },
  confirmBtn: { backgroundColor: "#22C55E", padding: 18, borderRadius: 14, alignItems: "center", marginBottom: 12 },
  confirmBtnText: { color: "#fff", fontWeight: "800", fontSize: 16 },
  cancelBtn: { padding: 14, alignItems: "center" },
  cancelBtnText: { color: "#64748B", fontSize: 14 },
  successTitle: { color: "#4ADE80", fontSize: 28, fontWeight: "800", marginTop: 12 },
  successSub: { color: "#94A3B8", fontSize: 15, textAlign: "center" },
  btn: { backgroundColor: "#3B82F6", padding: 16, borderRadius: 12, alignItems: "center", paddingHorizontal: 32 },
  btnText: { color: "#fff", fontWeight: "700", fontSize: 15 },
});
