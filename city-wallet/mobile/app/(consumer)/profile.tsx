import { useEffect, useState } from "react";
import { View, Text, StyleSheet, Switch, TouchableOpacity, SafeAreaView, ScrollView, Alert } from "react-native";
import { useRouter } from "expo-router";
import { getUser, removeToken, clearUser } from "@/services/storage";

export default function ProfileScreen() {
  const router = useRouter();
  const [user, setUser] = useState<Record<string, string> | null>(null);
  const [locationConsent, setLocationConsent] = useState(true);
  const [learningConsent, setLearningConsent] = useState(true);

  useEffect(() => { getUser().then(setUser); }, []);

  async function handleLogout() {
    await removeToken();
    await clearUser();
    router.replace("/(auth)/login");
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={styles.title}>Profile</Text>
        {user && (
          <View style={styles.card}>
            <Text style={styles.name}>{user.name || "You"}</Text>
            <Text style={styles.email}>{user.email}</Text>
          </View>
        )}

        <Text style={styles.sectionTitle}>Privacy & Data</Text>

        <View style={styles.privacyBox}>
          <Text style={styles.privacyHead}>How City Wallet protects your data</Text>
          <Text style={styles.privacyBody}>
            Your GPS coordinates are never stored. Each time you tap "Find Offers", only an
            abstract context signal (weather, approximate busyness level) is sent to generate
            your offer. The raw location stays on your device.
          </Text>
          <Text style={styles.privacyBody}>
            Offer generation uses Anthropic's Claude API — no personal movement data is shared
            with the model, only anonymised shop context.
          </Text>
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.toggleInfo}>
            <Text style={styles.toggleLabel}>Location while using app</Text>
            <Text style={styles.toggleSub}>Required to find nearby offers</Text>
          </View>
          <Switch
            value={locationConsent}
            onValueChange={setLocationConsent}
            trackColor={{ true: "#3B82F6" }}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.toggleInfo}>
            <Text style={styles.toggleLabel}>Preference learning</Text>
            <Text style={styles.toggleSub}>Improves future offers based on redemptions</Text>
          </View>
          <Switch
            value={learningConsent}
            onValueChange={setLearningConsent}
            trackColor={{ true: "#3B82F6" }}
          />
        </View>

        <TouchableOpacity style={styles.logoutBtn} onPress={() => Alert.alert("Log out?", "", [
          { text: "Cancel" },
          { text: "Log out", onPress: handleLogout, style: "destructive" },
        ])}>
          <Text style={styles.logoutText}>Log Out</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 20 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800", marginBottom: 20 },
  card: { backgroundColor: "#1E293B", borderRadius: 16, padding: 16, marginBottom: 24 },
  name: { color: "#F8FAFC", fontSize: 18, fontWeight: "700" },
  email: { color: "#64748B", fontSize: 13, marginTop: 2 },
  sectionTitle: { color: "#94A3B8", fontSize: 12, fontWeight: "700", textTransform: "uppercase", marginBottom: 12, letterSpacing: 1 },
  privacyBox: { backgroundColor: "#0D2035", borderRadius: 16, padding: 16, marginBottom: 20, gap: 8 },
  privacyHead: { color: "#60A5FA", fontWeight: "700", fontSize: 14, marginBottom: 4 },
  privacyBody: { color: "#94A3B8", fontSize: 13, lineHeight: 20 },
  toggleRow: { flexDirection: "row", alignItems: "center", padding: 16, backgroundColor: "#1E293B", borderRadius: 12, marginBottom: 10 },
  toggleInfo: { flex: 1 },
  toggleLabel: { color: "#F8FAFC", fontWeight: "600", fontSize: 14 },
  toggleSub: { color: "#64748B", fontSize: 11, marginTop: 2 },
  logoutBtn: { marginTop: 32, padding: 16, backgroundColor: "#1E293B", borderRadius: 12, alignItems: "center" },
  logoutText: { color: "#EF4444", fontWeight: "700" },
});
