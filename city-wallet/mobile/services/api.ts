import axios from "axios";
import { API_BASE_URL } from "@/constants/config";
import { getToken } from "./storage";

const api = axios.create({ baseURL: API_BASE_URL, timeout: 10_000 });

api.interceptors.request.use(async (config) => {
  const token = await getToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export default api;
