// moderate-content/index.ts
// Sightengine content moderation proxy for Z Chat.
// Credentials are NEVER exposed to Flutter clients.
// Supports: text, image URL moderation.
// Policy: If Sightengine is unavailable → allow_pending (configurable).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Types ────────────────────────────────────────────────────────────────────

type TargetType = "post" | "comment" | "moment" | "message" | "profile";

interface ModerationRequest {
  type: "text" | "image";
  content: string;          // Text content OR publicly accessible image URL
  target_type: TargetType;
  target_id: string;
  user_id?: string;
}

interface ModerationResult {
  status: "allowed" | "blocked" | "review" | "pending_moderation";
  category?: string;
  score?: number;
  reason?: string;
}

// ─── Thresholds ───────────────────────────────────────────────────────────────
// Scores from Sightengine range 0.0–1.0

const BLOCK_THRESHOLD = 0.85;   // >= this → block
const REVIEW_THRESHOLD = 0.50;  // >= this < BLOCK → review

// ─── CORS ─────────────────────────────────────────────────────────────────────

function corsHeaders(origin: string) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "*";

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // Read credentials from server secrets
  const API_USER = Deno.env.get("SIGHTENGINE_API_USER");
  const API_SECRET = Deno.env.get("SIGHTENGINE_API_SECRET");
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!API_USER || !API_SECRET) {
    console.warn("Sightengine credentials not configured — applying fallback policy");
    // Fallback policy: allow with pending_moderation flag
    return new Response(
      JSON.stringify({
        status: "pending_moderation",
        reason: "Moderation service temporarily unavailable",
      } as ModerationResult),
      {
        status: 200,
        headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
      }
    );
  }

  // Verify caller is authenticated
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // Parse body
  let body: ModerationRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  const { type, content, target_type, target_id, user_id } = body;

  if (!type || !content || !target_type || !target_id) {
    return new Response(JSON.stringify({ error: "Missing required fields: type, content, target_type, target_id" }), {
      status: 400,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  let result: ModerationResult;

  try {
    if (type === "text") {
      result = await moderateText(content, API_USER, API_SECRET);
    } else if (type === "image") {
      result = await moderateImage(content, API_USER, API_SECRET);
    } else {
      return new Response(JSON.stringify({ error: "Invalid moderation type. Use 'text' or 'image'" }), {
        status: 400,
        headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
      });
    }
  } catch (err) {
    console.error("Sightengine moderation error:", err);
    // Fallback policy: allow with pending flag (avoids blocking users during outages)
    result = {
      status: "pending_moderation",
      reason: "Moderation service temporarily unavailable",
    };
  }

  // Record event in DB (fire-and-forget, don't fail if recording fails)
  if (SUPABASE_URL && SUPABASE_SERVICE_KEY) {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      await supabase.from("moderation_events").insert({
        target_type,
        target_id,
        user_id: user_id ?? null,
        provider: "sightengine",
        status: result.status === "pending_moderation" ? "pending" : result.status,
        category: result.category ?? null,
        score: result.score ?? null,
      });
    } catch (dbErr) {
      console.error("Failed to record moderation event:", dbErr);
      // Don't fail the request because of DB recording failure
    }
  }

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
});

// ─── Text Moderation ──────────────────────────────────────────────────────────

async function moderateText(text: string, apiUser: string, apiSecret: string): Promise<ModerationResult> {
  // Trim and limit text sent to API
  const cleanText = text.trim().substring(0, 10000);
  if (!cleanText) return { status: "allowed" };

  const params = new URLSearchParams({
    text: cleanText,
    lang: "en",
    mode: "rules",
    api_user: apiUser,
    api_secret: apiSecret,
  });

  const res = await fetch(
    `https://api.sightengine.com/1.0/text/check.json?${params.toString()}`,
    { method: "GET" }
  );

  if (!res.ok) {
    throw new Error(`Sightengine text API returned ${res.status}`);
  }

  const data = await res.json();

  // Check for profanity / hate
  const profanity = data.profanity?.matches?.length > 0;
  const personalAttack = (data.personal?.prob ?? 0) >= REVIEW_THRESHOLD;
  const link = data.link?.matches?.length > 0;

  if (profanity) {
    const highSeverity = data.profanity.matches.some((m: { intensity: string }) => m.intensity === "high");
    if (highSeverity) {
      return { status: "blocked", category: "profanity", score: 1.0 };
    }
    return { status: "review", category: "profanity", score: 0.7 };
  }

  if (personalAttack && (data.personal?.prob ?? 0) >= BLOCK_THRESHOLD) {
    return { status: "blocked", category: "harassment", score: data.personal?.prob };
  }
  if (personalAttack) {
    return { status: "review", category: "harassment", score: data.personal?.prob };
  }

  return { status: "allowed" };
}

// ─── Image Moderation ─────────────────────────────────────────────────────────

async function moderateImage(imageUrl: string, apiUser: string, apiSecret: string): Promise<ModerationResult> {
  if (!imageUrl || !imageUrl.startsWith("http")) {
    throw new Error("Invalid image URL for moderation");
  }

  const params = new URLSearchParams({
    url: imageUrl,
    models: "nudity-2.1,weapon,recreational_drug,gore-2.0,hate-symbols",
    api_user: apiUser,
    api_secret: apiSecret,
  });

  const res = await fetch(
    `https://api.sightengine.com/1.0/check.json?${params.toString()}`,
    { method: "GET" }
  );

  if (!res.ok) {
    throw new Error(`Sightengine image API returned ${res.status}`);
  }

  const data = await res.json();

  // Check nudity
  const nudity = data.nudity;
  if (nudity) {
    const maxNudity = Math.max(
      nudity.erotica ?? 0,
      nudity.very_suggestive ?? 0,
      nudity.explicit ?? 0
    );
    if (maxNudity >= BLOCK_THRESHOLD) {
      return { status: "blocked", category: "nudity", score: maxNudity };
    }
    if (maxNudity >= REVIEW_THRESHOLD) {
      return { status: "review", category: "nudity", score: maxNudity };
    }
  }

  // Check gore
  const gore = data.gore?.prob ?? 0;
  if (gore >= BLOCK_THRESHOLD) {
    return { status: "blocked", category: "gore", score: gore };
  }
  if (gore >= REVIEW_THRESHOLD) {
    return { status: "review", category: "gore", score: gore };
  }

  // Check weapons
  const weapon = data.weapon?.classes?.firearm ?? 0;
  if (weapon >= BLOCK_THRESHOLD) {
    return { status: "blocked", category: "weapon", score: weapon };
  }

  // Check hate symbols
  const hate = data["hate-symbols"]?.prob ?? 0;
  if (hate >= BLOCK_THRESHOLD) {
    return { status: "blocked", category: "hate_symbols", score: hate };
  }

  return { status: "allowed" };
}
