import { Link, Stack } from "expo-router";
import { View, Text, StyleSheet } from "react-native";

export default function NotFound() {
  return (
    <>
      <Stack.Screen options={{ title: "Not Found" }} />
      <View style={styles.container}>
        <Text style={styles.text}>Screen not found</Text>
        <Link href="/(auth)/login">
          <Text style={styles.link}>Go to login</Text>
        </Link>
      </View>
    </>
  );
}
const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0F172A", justifyContent: "center", alignItems: "center" },
  text: { color: "#94A3B8", fontSize: 16 },
  link: { color: "#3B82F6", marginTop: 12 },
});
