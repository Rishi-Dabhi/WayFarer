import * as SecureStore from "expo-secure-store";
import AsyncStorage from "@react-native-async-storage/async-storage";

export async function saveToken(token: string) {
  await SecureStore.setItemAsync("jwt", token);
}

export async function getToken(): Promise<string | null> {
  return SecureStore.getItemAsync("jwt");
}

export async function removeToken() {
  await SecureStore.deleteItemAsync("jwt");
}

export async function saveUser(user: object) {
  await AsyncStorage.setItem("user", JSON.stringify(user));
}

export async function getUser(): Promise<Record<string, string> | null> {
  const raw = await AsyncStorage.getItem("user");
  return raw ? JSON.parse(raw) : null;
}

export async function clearUser() {
  await AsyncStorage.removeItem("user");
}
