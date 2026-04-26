import { useEffect, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, SafeAreaView, ScrollView, Alert } from "react-native";
import { useRouter } from "expo-router";
import { getUser, removeToken, clearUser } from "@/services/storage";

export default function MerchantProfileScreen() {
  const router = useRouter();
  const [user, setUser] = useState<Record<string, string> | null>(null);

  useEffect(() => {
    getUser().then(setUser);
  }, []);

  async function handleLogout() {
    await removeToken();
    await clearUser();
    router.replace("/(auth)/login");
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={styles.title}>Merchant Profile</Text>

        <View style={styles.card}>
          <Text style={styles.label}>Business Account</Text>
          <Text style={styles.name}>{user?.name || "Merchant"}</Text>
          <Text style={styles.email}>{user?.email || "-"}</Text>
          <Text style={styles.role}>Role: Merchant</Text>
        </View>

        <View style={styles.infoBox}>
          <Text style={styles.infoTitle}>Account</Text>
          <Text style={styles.infoText}>
            Use this profile page to securely sign out of the merchant dashboard.
          </Text>
        </View>

        <TouchableOpacity
          style={styles.logoutBtn}
          onPress={() =>
            Alert.alert("Log out?", "You will need to sign in again to manage your store.", [
              { text: "Cancel" },
              { text: "Log out", style: "destructive", onPress: handleLogout },
            ])
          }
        >
          <Text style={styles.logoutText}>Log Out</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  scroll: { padding: 20, paddingBottom: 40 },
  title: { color: "#F8FAFC", fontSize: 24, fontWeight: "800", marginBottom: 20 },
  card: { backgroundColor: "#1E293B", borderRadius: 16, padding: 16, marginBottom: 20 },
  label: { color: "#94A3B8", fontSize: 12, textTransform: "uppercase", marginBottom: 8, letterSpacing: 1 },
  name: { color: "#F8FAFC", fontSize: 20, fontWeight: "700" },
  email: { color: "#94A3B8", fontSize: 13, marginTop: 4 },
  role: { color: "#64748B", fontSize: 12, marginTop: 10 },
  infoBox: { backgroundColor: "#0D2035", borderRadius: 14, padding: 14, marginBottom: 26 },
  infoTitle: { color: "#60A5FA", fontSize: 14, fontWeight: "700", marginBottom: 6 },
  infoText: { color: "#94A3B8", fontSize: 13, lineHeight: 20 },
  logoutBtn: { backgroundColor: "#1E293B", borderRadius: 12, padding: 16, alignItems: "center" },
  logoutText: { color: "#EF4444", fontWeight: "800", fontSize: 14 },
});
