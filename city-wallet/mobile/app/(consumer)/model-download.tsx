import { useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { useGemma } from "@/hooks/useGemma";

export default function ModelDownloadScreen() {
  const router = useRouter();
  const gemma = useGemma();
  const [started, setStarted] = useState(false);

  async function start() {
    setStarted(true);
    await gemma.ensureReady();
    router.replace("/(consumer)");
  }

  const pct = Math.round(gemma.progress * 100);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Ionicons name="sparkles" size={42} color="#38BDF8" />
        <Text style={styles.title}>Prepare local AI</Text>
        <Text style={styles.body}>
          WayFarer can generate coupon copy on this phone with Gemma 3 1B. The demo also has a fallback if the model is not installed yet.
        </Text>
        {started && (
          <View style={styles.progressTrack}>
            <View style={[styles.progressFill, { width: `${pct}%` }]} />
          </View>
        )}
        {started && <Text style={styles.percent}>{pct}%</Text>}
        <TouchableOpacity style={styles.button} onPress={start} disabled={started && gemma.state !== "error"}>
          <Text style={styles.buttonText}>{started ? "Preparing..." : "Download model"}</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.skip} onPress={() => router.replace("/(consumer)")}>
          <Text style={styles.skipText}>Use demo fallback</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A" },
  content: { flex: 1, justifyContent: "center", padding: 24 },
  title: { color: "#F8FAFC", fontSize: 28, fontWeight: "900", marginTop: 16 },
  body: { color: "#94A3B8", lineHeight: 22, marginTop: 10, marginBottom: 24 },
  progressTrack: { height: 10, borderRadius: 8, backgroundColor: "#1E293B", overflow: "hidden", marginBottom: 8 },
  progressFill: { height: 10, backgroundColor: "#38BDF8" },
  percent: { color: "#CBD5E1", fontWeight: "800", marginBottom: 16 },
  button: { height: 52, borderRadius: 8, backgroundColor: "#2563EB", alignItems: "center", justifyContent: "center" },
  buttonText: { color: "#fff", fontWeight: "900" },
  skip: { alignItems: "center", padding: 16 },
  skipText: { color: "#94A3B8", fontWeight: "700" },
});

