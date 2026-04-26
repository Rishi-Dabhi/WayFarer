import { useCallback, useState } from "react";
import api from "@/services/api";
import { GeneratedOffer, downloadModel, generateOfferWithGemma, modelExists } from "@/services/gemmaService";
import { getUser } from "@/services/storage";

type GemmaState = "idle" | "downloading" | "ready" | "generating" | "error";

export function useGemma() {
  const [state, setState] = useState<GemmaState>("idle");
  const [progress, setProgress] = useState(0);
  const [streamingText, setStreamingText] = useState("");
  const [error, setError] = useState<string | null>(null);

  const ensureReady = useCallback(async () => {
    setError(null);
    if (!(await modelExists())) {
      setState("downloading");
      await downloadModel(setProgress);
    }
    setState("ready");
  }, []);

  const generateForShop = useCallback(
    async (shopDetail: any, contextSignals: any): Promise<any | null> => {
      setState("generating");
      setStreamingText("");
      setError(null);
      try {
        const prompt = buildPrompt(shopDetail, contextSignals);
        const generated: GeneratedOffer = await generateOfferWithGemma(prompt);
        setStreamingText(generated.headline);

        const user = await getUser();
        const product = shopDetail.products?.[0];
        const { data } = await api.post("/api/coupons", {
          shop_id: shopDetail.shop.id,
          user_id: user?.user_id ? Number(user.user_id) : undefined,
          headline: generated.headline,
          body_text: generated.body_text,
          why_now: generated.why_now,
          discount_pct: generated.discount_pct,
          cashback_cents: generated.cashback_cents,
          product_id: product?.id,
          context_snapshot: contextSignals ?? {},
          expires_minutes: generated.expires_minutes,
        });

        setState("ready");
        return { ...generated, id: data.id, coupon_id: data.coupon_id, qr_token: data.qr_token };
      } catch {
        setState("error");
        setError("Could not generate offer");
        return null;
      }
    },
    []
  );

  return { state, progress, streamingText, error, ensureReady, generateForShop };
}

function buildPrompt(shopDetail: any, context: any) {
  const shop = shopDetail.shop;
  const products = (shopDetail.products ?? [])
    .map((p: any) => `${p.name} EUR ${(p.price_cents / 100).toFixed(2)} stock=${p.stock_level}`)
    .join("; ");
  const weather = context?.weather;
  const time = context?.time;
  const busyness = shopDetail.busyness;
  return `<start_of_turn>user
You are an offer engine for a city wallet app. Generate ONE JSON offer for a person right now.

Shop: ${shop.name}, category: ${shop.category}, goal: ${shop.campaign_goal}
Products: ${products}
Context: ${weather?.temp ?? "unknown"}C, ${weather?.condition ?? "unknown"}, ${time?.period ?? "now"} on ${time?.day_of_week ?? "today"}
Shop busyness: ${busyness?.busyness ?? "normal"} (${busyness?.txn_count_15min ?? 0} transactions in last 15 min)

Return ONLY valid JSON with headline, body_text, why_now, discount_pct, cashback_cents, product_name, expires_minutes.
<end_of_turn>
<start_of_turn>model`;
}

