import { useState } from "react";
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, KeyboardAvoidingView, Platform } from "react-native";
import { useRouter } from "expo-router";
import api from "@/services/api";
import { saveToken, saveUser } from "@/services/storage";

export default function LoginScreen() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleLogin() {
    setLoading(true);
    try {
      const { data } = await api.post("/api/auth/login", { email, password });
      await saveToken(data.token);
      await saveUser({ role: data.role, user_id: String(data.user_id), name: data.name, email });
      router.replace(data.role === "merchant" ? "/(merchant)" : "/(consumer)");
    } catch {
      Alert.alert("Login failed", "Check your email and password");
    } finally {
      setLoading(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <View style={styles.inner}>
        <Text style={styles.logo}>City Wallet</Text>
        <Text style={styles.sub}>Hyper-local offers, generated for you</Text>

        <TextInput
          style={styles.input}
          placeholder="Email"
          placeholderTextColor="#64748B"
          value={email}
          onChangeText={setEmail}
          autoCapitalize="none"
          keyboardType="email-address"
        />
        <TextInput
          style={styles.input}
          placeholder="Password"
          placeholderTextColor="#64748B"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
        />

        <TouchableOpacity style={styles.btn} onPress={handleLogin} disabled={loading}>
          <Text style={styles.btnText}>{loading ? "Signing in..." : "Sign In"}</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={() => router.push("/(auth)/register")}>
          <Text style={styles.link}>Don't have an account? Register →</Text>
        </TouchableOpacity>

        <Text style={styles.demo}>Demo: user@demo.com / merchant@demo.com (pw: demo1234)</Text>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  inner: { flex: 1, justifyContent: "center", padding: 24 },
  logo: { color: "#F8FAFC", fontSize: 34, fontWeight: "800", marginBottom: 4 },
  sub: { color: "#64748B", fontSize: 15, marginBottom: 40 },
  input: {
    backgroundColor: "#1E293B",
    color: "#F8FAFC",
    padding: 14,
    borderRadius: 12,
    marginBottom: 12,
    fontSize: 15,
  },
  btn: { backgroundColor: "#3B82F6", padding: 16, borderRadius: 12, alignItems: "center", marginTop: 8 },
  btnText: { color: "#fff", fontWeight: "700", fontSize: 16 },
  link: { color: "#3B82F6", textAlign: "center", marginTop: 20, fontSize: 14 },
  demo: { color: "#334155", textAlign: "center", marginTop: 32, fontSize: 11 },
});
