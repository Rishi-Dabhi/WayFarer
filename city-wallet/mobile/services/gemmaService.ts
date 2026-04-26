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
  const llama = await import("llama.rn");
  if (!llama) throw new Error("llama.rn module not available");

  const context = await llama.initLlama({ model: MODEL_FILE });
  if (!context) throw new Error("Failed to initialise Gemma context");

  const result = await context.completion({ prompt, n_predict: 400, temperature: 0.7 });
  const text = typeof result === "string" ? result : result?.text ?? "";

  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error("Gemma did not return valid JSON");

  return JSON.parse(jsonMatch[0]) as GeneratedOffer;
}
