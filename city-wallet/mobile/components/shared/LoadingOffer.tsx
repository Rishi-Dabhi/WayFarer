import React, { useEffect, useRef } from "react";
import { View, Text, Animated, StyleSheet } from "react-native";

interface Props {
  streamingText?: string;
}

export default function LoadingOffer({ streamingText }: Props) {
  const opacity = useRef(new Animated.Value(0.3)).current;

  useEffect(() => {
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, { toValue: 1, duration: 700, useNativeDriver: true }),
        Animated.timing(opacity, { toValue: 0.3, duration: 700, useNativeDriver: true }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [opacity]);

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <Text style={styles.label}>Generating your offer...</Text>
        <Animated.View style={[styles.dot, { opacity }]} />
      </View>
      {streamingText ? (
        <Text style={styles.streaming}>{streamingText}</Text>
      ) : (
        <>
          <Animated.View style={[styles.shimmer, { opacity, width: "70%" }]} />
          <Animated.View style={[styles.shimmer, { opacity, width: "100%", marginTop: 8 }]} />
          <Animated.View style={[styles.shimmer, { opacity, width: "80%", marginTop: 8 }]} />
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    margin: 16,
    padding: 20,
    borderRadius: 20,
    backgroundColor: "#1E293B",
    minHeight: 160,
  },
  header: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 16 },
  label: { color: "#94A3B8", fontSize: 13 },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: "#3B82F6" },
  shimmer: { height: 14, borderRadius: 7, backgroundColor: "#334155" },
  streaming: { color: "#E2E8F0", fontSize: 13, lineHeight: 20 },
});
