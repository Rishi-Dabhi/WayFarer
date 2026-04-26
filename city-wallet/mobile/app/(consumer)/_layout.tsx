import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";

export default function ConsumerLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: "#0F172A", borderTopColor: "#1E293B" },
        tabBarActiveTintColor: "#3B82F6",
        tabBarInactiveTintColor: "#475569",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: "Map", tabBarIcon: ({ color, size }) => <Ionicons name="map" size={size} color={color} /> }}
      />
      <Tabs.Screen
        name="wallet"
        options={{ title: "Wallet", tabBarIcon: ({ color, size }) => <Ionicons name="wallet" size={size} color={color} /> }}
      />
      <Tabs.Screen
        name="profile"
        options={{ title: "Profile", tabBarIcon: ({ color, size }) => <Ionicons name="person" size={size} color={color} /> }}
      />
      <Tabs.Screen name="offer/[id]" options={{ href: null }} />
      <Tabs.Screen name="shop/[id]" options={{ href: null }} />
      <Tabs.Screen name="model-download" options={{ href: null }} />
    </Tabs>
  );
}
