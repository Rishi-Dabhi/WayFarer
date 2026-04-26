import React from "react";
import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { Coupon } from "@/hooks/useOfferStream";

const TONE_COLORS: Record<string, string> = {
  warm: "#F97316",
  urgent: "#EF4444",
  playful: "#A855F7",
  calm: "#3B82F6",
};

interface Props {
  coupon: Coupon;
}

export default function OfferCard({ coupon }: Props) {
  const router = useRouter();
  const accentColor = TONE_COLORS[coupon.tone] ?? "#3B82F6";

  return (
    <TouchableOpacity
      style={[styles.card, { borderColor: accentColor }]}
      onPress={() => router.push(`/(consumer)/offer/${coupon.id}`)}
      activeOpacity={0.85}
    >
      {/* Discount badge */}
      <View style={[styles.badge, { backgroundColor: accentColor }]}>
        <Text style={styles.badgeText}>{coupon.discount_pct}% off</Text>
      </View>

      {/* Headline — 3-second comprehension */}
      <Text style={styles.headline}>{coupon.headline}</Text>

      {/* Shop + distance */}
      <Text style={styles.shopLine}>
        {coupon.shop_name}
        {coupon.product_name ? ` · ${coupon.product_name}` : ""}
      </Text>

      {/* Body */}
      <Text style={styles.body} numberOfLines={3}>
        {coupon.body_text}
      </Text>

      {/* Cashback row */}
      <View style={styles.footer}>
        <Text style={styles.cashback}>
          €{(coupon.cashback_cents / 100).toFixed(2)} cashback
        </Text>
        <TouchableOpacity
          style={[styles.cta, { backgroundColor: accentColor }]}
          onPress={() => router.push(`/(consumer)/offer/${coupon.id}`)}
        >
          <Text style={styles.ctaText}>Claim Offer →</Text>
        </TouchableOpacity>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    margin: 16,
    padding: 20,
    borderRadius: 20,
    backgroundColor: "#1E293B",
    borderWidth: 1.5,
  },
  badge: {
    alignSelf: "flex-end",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    marginBottom: 12,
  },
  badgeText: { color: "#fff", fontWeight: "800", fontSize: 13 },
  headline: {
    color: "#F8FAFC",
    fontSize: 26,
    fontWeight: "800",
    lineHeight: 32,
    marginBottom: 6,
  },
  shopLine: { color: "#94A3B8", fontSize: 13, marginBottom: 12 },
  body: { color: "#CBD5E1", fontSize: 14, lineHeight: 21, marginBottom: 16 },
  footer: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  cashback: { color: "#4ADE80", fontWeight: "700", fontSize: 14 },
  cta: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: 12 },
  ctaText: { color: "#fff", fontWeight: "700", fontSize: 13 },
});
