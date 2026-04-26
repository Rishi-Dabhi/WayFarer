import { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, Alert, SafeAreaView, Switch } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import api from "@/services/api";
import { getUser } from "@/services/storage";

const GOALS = [
  { key: "fill_quiet_hours", label: "Fill Quiet Hours", icon: "time" },
  { key: "clear_stock", label: "Clear Stock", icon: "cube" },
  { key: "new_customers", label: "Attract New Customers", icon: "people" },
];

const QUIET_HOUR_OPTIONS = ["09:00-11:00", "14:00-16:00", "15:00-17:00", "20:00-22:00"];

export default function CampaignScreen() {
  const [shopId, setShopId] = useState<number | null>(null);
  const [maxDiscount, setMaxDiscount] = useState("20");
  const [cashbackBudget, setCashbackBudget] = useState("5");
  const [goal, setGoal] = useState("fill_quiet_hours");
  const [quietHours, setQuietHours] = useState<string[]>(["14:00-16:00"]);
  const [isActive, setIsActive] = useState(true);
  const [autoCouponEnabled, setAutoCouponEnabled] = useState(true);
  const [triggerRadius, setTriggerRadius] = useState("200");
  const [quietThreshold, setQuietThreshold] = useState("60");
  const [frequencyMinutes, setFrequencyMinutes] = useState("60");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const user = await getUser();
    if (!user) return;
    const { data: shops } = await api.get(`/api/merchants/shop/${user.user_id}`);
    if (shops.length === 0) return;
    const shop = shops[0];
    setShopId(shop.id);
    setMaxDiscount(String(shop.max_discount_pct));
    setCashbackBudget(String(shop.cashback_budget_per_coupon_cents / 100));
    setGoal(shop.campaign_goal || "fill_quiet_hours");
    setIsActive(shop.is_active === 1);
    setAutoCouponEnabled((shop.auto_coupon_enabled ?? 1) === 1);
    setTriggerRadius(String(shop.auto_trigger_radius_m ?? 200));
    setQuietThreshold(String(Math.round((shop.quiet_threshold_ratio ?? 0.6) * 100)));
    setFrequencyMinutes(String(shop.coupon_frequency_minutes ?? 60));
    try {
      const parsed = JSON.parse(shop.target_quiet_hours || "[]");
      setQuietHours(Array.isArray(parsed) ? parsed : []);
    } catch { setQuietHours([]); }
  }, []);

  useEffect(() => { load(); }, [load]);

  function toggleHour(h: string) {
    setQuietHours((prev) => prev.includes(h) ? prev.filter((x) => x !== h) : [...prev, h]);
  }

  async function handleSave() {
    if (!shopId) return;
    setSaving(true);
    try {
      await api.put(`/api/merchants/shop/${shopId}`, {
        max_discount_pct: parseInt(maxDiscount),
        cashback_budget_per_coupon_cents: Math.round(parseFloat(cashbackBudget) * 100),
        campaign_goal: goal,
        target_quiet_hours: quietHours,
        auto_coupon_enabled: autoCouponEnabled ? 1 : 0,
        auto_trigger_radius_m: parseInt(triggerRadius),
        quiet_threshold_ratio: parseFloat(quietThreshold) / 100,
        coupon_frequency_minutes: parseInt(frequencyMinutes),
        is_active: isActive ? 1 : 0,
      });
      Alert.alert("Saved", "Campaign rules updated");
    } catch {
      Alert.alert("Error", "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={styles.title}>Campaign Rules</Text>
        <Text style={styles.subtitle}>The AI creates the actual offer. You set the rules.</Text>

        <View style={styles.activeRow}>
          <Text style={styles.label}>Campaign Active</Text>
          <Switch value={isActive} onValueChange={setIsActive} trackColor={{ true: "#22C55E" }} />
        </View>

        <View style={styles.activeRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>Automatic Coupons</Text>
            <Text style={styles.help}>Backend creates offers when live context matches these rules.</Text>
          </View>
          <Switch value={autoCouponEnabled} onValueChange={setAutoCouponEnabled} trackColor={{ true: "#22C55E" }} />
        </View>

        <Text style={styles.sectionLabel}>Campaign Goal</Text>
        {GOALS.map((g) => (
          <TouchableOpacity
            key={g.key}
            style={[styles.goalBtn, goal === g.key && styles.goalBtnActive]}
            onPress={() => setGoal(g.key)}
          >
            <Ionicons name={g.icon as never} size={18} color={goal === g.key ? "#F97316" : "#64748B"} />
            <Text style={[styles.goalText, goal === g.key && styles.goalTextActive]}>{g.label}</Text>
            {goal === g.key && <Ionicons name="checkmark" size={16} color="#F97316" />}
          </TouchableOpacity>
        ))}

        <Text style={styles.sectionLabel}>Max Discount (%)</Text>
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={maxDiscount}
            onChangeText={setMaxDiscount}
            keyboardType="numeric"
            placeholder="20"
            placeholderTextColor="#64748B"
          />
          <Text style={styles.inputUnit}>%</Text>
        </View>

        <Text style={styles.sectionLabel}>Max Cashback per Coupon (€)</Text>
        <View style={styles.inputRow}>
          <Text style={styles.inputUnit}>€</Text>
          <TextInput
            style={styles.input}
            value={cashbackBudget}
            onChangeText={setCashbackBudget}
            keyboardType="decimal-pad"
            placeholder="5.00"
            placeholderTextColor="#64748B"
          />
        </View>

        <Text style={styles.sectionLabel}>Auto Trigger Radius (m)</Text>
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={triggerRadius}
            onChangeText={setTriggerRadius}
            keyboardType="numeric"
            placeholder="200"
            placeholderTextColor="#64748B"
          />
          <Text style={styles.inputUnit}>m</Text>
        </View>

        <Text style={styles.sectionLabel}>Quiet Threshold (%)</Text>
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={quietThreshold}
            onChangeText={setQuietThreshold}
            keyboardType="numeric"
            placeholder="60"
            placeholderTextColor="#64748B"
          />
          <Text style={styles.inputUnit}>%</Text>
        </View>

        <Text style={styles.sectionLabel}>Minimum Frequency (minutes)</Text>
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={frequencyMinutes}
            onChangeText={setFrequencyMinutes}
            keyboardType="numeric"
            placeholder="60"
            placeholderTextColor="#64748B"
          />
          <Text style={styles.inputUnit}>min</Text>
        </View>

        <Text style={styles.sectionLabel}>Target Quiet Hours</Text>
        <View style={styles.hoursGrid}>
          {QUIET_HOUR_OPTIONS.map((h) => (
            <TouchableOpacity
              key={h}
              style={[styles.hourChip, quietHours.includes(h) && styles.hourChipActive]}
              onPress={() => toggleHour(h)}
            >
              <Text style={[styles.hourText, quietHours.includes(h) && styles.hourTextActive]}>{h}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.saveBtn} onPress={handleSave} disabled={saving}>
          <Text style={styles.saveBtnText}>{saving ? "Saving..." : "Save Campaign Rules"}</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 16, paddingBottom: 40 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800", marginBottom: 4 },
  subtitle: { color: "#64748B", fontSize: 13, marginBottom: 24 },
  activeRow: { flexDirection: "row", alignItems: "center", backgroundColor: "#1E293B", borderRadius: 12, padding: 16, marginBottom: 20 },
  label: { flex: 1, color: "#F8FAFC", fontWeight: "600" },
  help: { color: "#64748B", fontSize: 11, marginTop: 4, lineHeight: 16 },
  sectionLabel: { color: "#94A3B8", fontSize: 12, fontWeight: "700", textTransform: "uppercase", marginBottom: 10, marginTop: 16, letterSpacing: 1 },
  goalBtn: { flexDirection: "row", alignItems: "center", gap: 12, padding: 14, backgroundColor: "#1E293B", borderRadius: 12, marginBottom: 8, borderWidth: 1, borderColor: "#1E293B" },
  goalBtnActive: { borderColor: "#F97316", backgroundColor: "#1A0D00" },
  goalText: { flex: 1, color: "#64748B", fontWeight: "600" },
  goalTextActive: { color: "#F97316" },
  inputRow: { flexDirection: "row", alignItems: "center", backgroundColor: "#1E293B", borderRadius: 12, paddingHorizontal: 14 },
  input: { flex: 1, color: "#F8FAFC", fontSize: 18, padding: 14 },
  inputUnit: { color: "#64748B", fontSize: 16 },
  hoursGrid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  hourChip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, borderWidth: 1, borderColor: "#334155" },
  hourChipActive: { borderColor: "#F97316", backgroundColor: "#1A0D00" },
  hourText: { color: "#64748B", fontWeight: "600", fontSize: 13 },
  hourTextActive: { color: "#F97316" },
  saveBtn: { marginTop: 32, backgroundColor: "#F97316", padding: 18, borderRadius: 14, alignItems: "center" },
  saveBtnText: { color: "#fff", fontWeight: "800", fontSize: 16 },
});
