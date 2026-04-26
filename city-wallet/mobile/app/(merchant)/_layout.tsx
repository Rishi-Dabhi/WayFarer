import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";

export default function MerchantLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: "#0F172A", borderTopColor: "#1E293B" },
        tabBarActiveTintColor: "#F97316",
        tabBarInactiveTintColor: "#475569",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: "Dashboard", tabBarIcon: ({ color, size }) => <Ionicons name="bar-chart" size={size} color={color} /> }}
      />
      <Tabs.Screen
        name="products"
        options={{ title: "Products", tabBarIcon: ({ color, size }) => <Ionicons name="grid" size={size} color={color} /> }}
      />
      <Tabs.Screen
        name="campaign"
        options={{ title: "Campaign", tabBarIcon: ({ color, size }) => <Ionicons name="settings" size={size} color={color} /> }}
      />
      <Tabs.Screen
        name="scan"
        options={{ title: "Scan QR", tabBarIcon: ({ color, size }) => <Ionicons name="qr-code" size={size} color={color} /> }}
      />
      <Tabs.Screen
        name="wallet"
        options={{ title: "Wallet", tabBarIcon: ({ color, size }) => <Ionicons name="wallet" size={size} color={color} /> }}
      />
      <Tabs.Screen name="analytics" options={{ href: null }} />
      <Tabs.Screen name="products/new" options={{ href: null }} />
    </Tabs>
  );
}
