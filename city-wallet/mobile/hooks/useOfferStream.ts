import { useState, useCallback } from "react";
import { API_BASE_URL } from "@/constants/config";
import { getToken } from "@/services/storage";

export interface Coupon {
  id: number;
  headline: string;
  body_text: string;
  why_now: string;
  discount_pct: number;
  cashback_cents: number;
  product_name: string | null;
  expires_at: string;
  qr_token: string;
  shop_name: string;
  shop_id: number;
  tone: string;
}

export function useOfferStream() {
  const [offer, setOffer] = useState<Coupon | null>(null);
  const [streamingText, setStreamingText] = useState("");
  const [loading, setLoading] = useState(false);
  const [signals, setSignals] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState<string | null>(null);

  const generate = useCallback(
    async (lat: number, lng: number, userId?: number, demo?: string) => {
      setLoading(true);
      setOffer(null);
      setStreamingText("");
      setError(null);

      try {
        const token = await getToken();
        const params = new URLSearchParams({
          user_lat: String(lat),
          user_lng: String(lng),
          ...(userId ? { user_id: String(userId) } : {}),
          ...(demo ? { demo } : {}),
        });

        const response = await fetch(
          `${API_BASE_URL}/api/offers/generate?${params}`,
          {
            method: "POST",
            headers: {
              Accept: "text/event-stream",
              ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
          }
        );

        if (!response.body) throw new Error("No response body");
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() ?? "";

          for (const line of lines) {
            if (!line.startsWith("data: ")) continue;
            const raw = line.slice(6).trim();
            if (!raw) continue;
            const event = JSON.parse(raw);

            if (event.type === "context") setSignals(event.payload);
            if (event.type === "token") setStreamingText((t) => t + event.payload.text);
            if (event.type === "offer") {
              setOffer(event.payload);
              setStreamingText("");
            }
            if (event.type === "error") setError(event.payload.message);
          }
        }
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : "Failed to generate offer");
      } finally {
        setLoading(false);
      }
    },
    []
  );

  return { generate, offer, streamingText, loading, signals, error };
}
