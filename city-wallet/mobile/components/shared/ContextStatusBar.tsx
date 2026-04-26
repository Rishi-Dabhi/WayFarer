import React from "react";
import { View, Text, ScrollView, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { ContextSignals } from "@/hooks/useContextSignals";

const BUSYNESS_COLOR: Record<string, string> = {
  quiet: "#22C55E",
  normal: "#F59E0B",
  busy: "#EF4444",
};

interface Props {
  signals: ContextSignals | null;
}

export default function ContextStatusBar({ signals }: Props) {
  if (!signals) return null;

  const shop = signals.nearby_shops[0];
  const event = signals.local_events[0];
  const density = signals.osm_density;

  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.scroll} contentContainerStyle={styles.row}>
      <Pill icon="thermometer" color="#60A5FA">
        {signals.weather.temp}°C · {signals.weather.condition}
      </Pill>
      <Pill icon="time" color="#A78BFA">
        {signals.time.period} · {signals.time.day_of_week}
      </Pill>
      {shop && (
        <Pill icon="pulse" color={BUSYNESS_COLOR[shop.busyness] ?? "#F59E0B"}>
          {shop.name} · {shop.busyness}
        </Pill>
      )}
      {density?.total > 0 && (
        <Pill icon="business" color="#34D399">
          {density.total} venues nearby
        </Pill>
      )}
      {event && (
        <Pill icon="musical-notes" color="#F97316">
          {event.name} · {event.distance_m}m
        </Pill>
      )}
    </ScrollView>
  );
}

function Pill({ icon, color, children }: { icon: string; color: string; children: React.ReactNode }) {
  return (
    <View style={[styles.pill, { borderColor: color }]}>
      <Ionicons name={icon as never} size={12} color={color} />
      <Text style={[styles.pillText, { color }]}>{children}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { flexGrow: 0 },
  row: { flexDirection: "row", gap: 8, paddingHorizontal: 16, paddingVertical: 10 },
  pill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 20,
    borderWidth: 1,
    backgroundColor: "rgba(255,255,255,0.05)",
  },
  pillText: { fontSize: 11, fontWeight: "600" },
});
