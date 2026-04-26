import { useState } from "react";
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, KeyboardAvoidingView, Platform } from "react-native";
import { useRouter } from "expo-router";
import api from "@/services/api";
import { saveToken, saveUser } from "@/services/storage";

export default function RegisterScreen() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [role, setRole] = useState<"consumer" | "merchant">("consumer");
  const [loading, setLoading] = useState(false);

  async function handleRegister() {
    setLoading(true);
    try {
      const { data } = await api.post("/api/auth/register", { email, password, name, role });
      await saveToken(data.token);
      await saveUser({ role: data.role, user_id: String(data.user_id), name: data.name, email });
      router.replace(data.role === "merchant" ? "/(merchant)" : "/(consumer)");
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? "Registration failed";
      Alert.alert("Error", msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <View style={styles.inner}>
        <Text style={styles.title}>Create Account</Text>

        <TextInput style={styles.input} placeholder="Full name" placeholderTextColor="#64748B" value={name} onChangeText={setName} />
        <TextInput style={styles.input} placeholder="Email" placeholderTextColor="#64748B" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" />
        <TextInput style={styles.input} placeholder="Password" placeholderTextColor="#64748B" value={password} onChangeText={setPassword} secureTextEntry />

        <View style={styles.roleRow}>
          {(["consumer", "merchant"] as const).map((r) => (
            <TouchableOpacity key={r} style={[styles.roleBtn, role === r && styles.roleBtnActive]} onPress={() => setRole(r)}>
              <Text style={[styles.roleBtnText, role === r && styles.roleBtnTextActive]}>
                {r === "consumer" ? "Shopper" : "Merchant"}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.btn} onPress={handleRegister} disabled={loading}>
          <Text style={styles.btnText}>{loading ? "Creating..." : "Create Account"}</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={() => router.back()}>
          <Text style={styles.link}>← Back to login</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  inner: { flex: 1, justifyContent: "center", padding: 24 },
  title: { color: "#F8FAFC", fontSize: 28, fontWeight: "800", marginBottom: 32 },
  input: { backgroundColor: "#1E293B", color: "#F8FAFC", padding: 14, borderRadius: 12, marginBottom: 12, fontSize: 15 },
  roleRow: { flexDirection: "row", gap: 12, marginBottom: 20 },
  roleBtn: { flex: 1, padding: 14, borderRadius: 12, borderWidth: 1.5, borderColor: "#334155", alignItems: "center" },
  roleBtnActive: { borderColor: "#3B82F6", backgroundColor: "#1E3A5F" },
  roleBtnText: { color: "#64748B", fontWeight: "600" },
  roleBtnTextActive: { color: "#3B82F6" },
  btn: { backgroundColor: "#3B82F6", padding: 16, borderRadius: 12, alignItems: "center" },
  btnText: { color: "#fff", fontWeight: "700", fontSize: 16 },
  link: { color: "#3B82F6", textAlign: "center", marginTop: 20, fontSize: 14 },
});
