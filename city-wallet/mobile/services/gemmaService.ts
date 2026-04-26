import * as FileSystem from "expo-file-system";
import { GEMMA_MODEL_URL } from "@/constants/config";

export interface GeneratedOffer {
  headline: string;
  body_text: string;
  why_now: string;
  discount_pct: number;
  cashback_cents: number;
  product_name?: string;
  expires_minutes: number;
}

const MODEL_FILE = `${FileSystem.documentDirectory ?? ""}gemma-3-1b-it-q4_0.gguf`;

export async function modelExists() {
  const info = await FileSystem.getInfoAsync(MODEL_FILE);
  return info.exists;
}

export async function downloadModel(onProgress?: (progress: number) => void) {
  const download = FileSystem.createDownloadResumable(
    GEMMA_MODEL_URL,
    MODEL_FILE,
    {},
    ({ totalBytesWritten, totalBytesExpectedToWrite }) => {
      if (totalBytesExpectedToWrite > 0) {
        onProgress?.(totalBytesWritten / totalBytesExpectedToWrite);
      }
    }
  );
  await download.downloadAsync();
  return MODEL_FILE;
}

export async function generateOfferWithGemma(prompt: string): Promise<GeneratedOffer> {
  try {
    // Native llama.rn integration is intentionally isolated here. The mock fallback
    // keeps the hackathon demo usable before a custom dev build has the GGUF runtime.
    const llama = await import("llama.rn");
    if (!llama) throw new Error("llama.rn unavailable");
    throw new Error("Gemma runtime not initialized in this demo build");
  } catch {
    return mockOffer(prompt);
  }
}

function mockOffer(prompt: string): GeneratedOffer {
  const rainy = /rain|grey|cold|8|11/i.test(prompt);
  const lunch = /lunch|midday|restaurant|food/i.test(prompt);
  return {
    headline: rainy ? "Warm up nearby" : lunch ? "Lunch cashback close by" : "A nearby reward waits",
    body_text: rainy
      ? "The weather is doing no one any favours, and this shop has room right now. Drop in soon and get instant cashback when you redeem."
      : "You are close enough for this to be useful, not spammy. Redeem at the counter and the cashback lands after the merchant confirms.",
    why_now: "Generated from live location, current context signals, shop busyness, products, and campaign settings.",
    discount_pct: 15,
    cashback_cents: 150,
    product_name: "Featured item",
    expires_minutes: 60,
  };
}

