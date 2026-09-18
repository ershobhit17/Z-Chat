// youtube-search/index.ts
// Secure YouTube Data API v3 proxy for Z Chat Watch section.
// NEVER exposes the API key to Flutter clients.
// Includes in-memory caching, rate limiting, and sanitized output.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ─── Types ────────────────────────────────────────────────────────────────────

interface SearchResult {
  video_id: string;
  title: string;
  thumbnail_url: string;
  channel_title: string;
  channel_id: string;
  published_at: string;
  duration?: string;
}

interface CacheEntry {
  results: SearchResult[];
  timestamp: number;
}

// ─── In-Memory Cache (per-instance, resets on cold start) ─────────────────────

const cache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// ─── Rate Limiting (per-instance, simple sliding window) ──────────────────────

const rateLimitMap = new Map<string, number[]>();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX = 20; // max 20 requests per IP per minute

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;
  const requests = (rateLimitMap.get(ip) ?? []).filter((t) => t > windowStart);
  requests.push(now);
  rateLimitMap.set(ip, requests);
  return requests.length > RATE_LIMIT_MAX;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function corsHeaders(origin: string) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

function sanitizeString(s: unknown, maxLen = 200): string {
  if (typeof s !== "string") return "";
  return s.trim().substring(0, maxLen);
}

// YouTube ISO 8601 duration → human-readable (e.g. PT4M13S → 4:13)
function formatDuration(iso: string | undefined): string | undefined {
  if (!iso) return undefined;
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return undefined;
  const h = parseInt(match[1] ?? "0");
  const m = parseInt(match[2] ?? "0");
  const s = parseInt(match[3] ?? "0");
  if (h > 0) {
    return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }
  return `${m}:${String(s).padStart(2, "0")}`;
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "*";

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // Rate limit by IP
  const clientIp = req.headers.get("x-forwarded-for") ?? req.headers.get("x-real-ip") ?? "unknown";
  if (isRateLimited(clientIp)) {
    return new Response(JSON.stringify({ error: "Too many requests. Please wait a moment." }), {
      status: 429,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // Read API key from server secret (NEVER exposed to client)
  const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY");
  if (!YOUTUBE_API_KEY) {
    console.error("YOUTUBE_API_KEY secret is not configured");
    return new Response(JSON.stringify({ error: "Watch is temporarily unavailable. Please try again later." }), {
      status: 503,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // Parse request body
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  const query = sanitizeString(body.query, 100);
  const pageToken = sanitizeString(body.page_token, 50);
  const maxResults = Math.min(Math.max(parseInt(String(body.max_results ?? "20")), 5), 50);

  if (!query || query.length < 2) {
    return new Response(JSON.stringify({ error: "Query must be at least 2 characters" }), {
      status: 400,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // Check cache (cache key includes page token)
  const cacheKey = `${query}::${pageToken}::${maxResults}`;
  const cached = cache.get(cacheKey);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return new Response(JSON.stringify({ results: cached.results, cached: true }), {
      status: 200,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // ── Step 1: YouTube Search API ────────────────────────────────────────────

  const searchParams = new URLSearchParams({
    part: "snippet",
    q: query,
    type: "video",
    maxResults: String(maxResults),
    key: YOUTUBE_API_KEY,
    videoEmbeddable: "true",
    safeSearch: "moderate",
    ...(pageToken ? { pageToken } : {}),
  });

  let videoIds: string[] = [];
  let nextPageToken: string | undefined;
  let searchSnippets: Record<string, { title: string; channelTitle: string; channelId: string; publishedAt: string; thumbnailUrl: string }> = {};

  try {
    const searchRes = await fetch(
      `https://www.googleapis.com/youtube/v3/search?${searchParams.toString()}`,
      { headers: { "Accept": "application/json" } }
    );

    if (!searchRes.ok) {
      const errText = await searchRes.text();
      console.error(`YouTube search API error ${searchRes.status}: ${errText}`);
      return new Response(JSON.stringify({ error: "Watch is temporarily unavailable. Please try again later." }), {
        status: 503,
        headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
      });
    }

    const searchData = await searchRes.json();
    nextPageToken = searchData.nextPageToken;

    for (const item of searchData.items ?? []) {
      const vid = item.id?.videoId;
      if (!vid) continue;
      videoIds.push(vid);

      const snippet = item.snippet ?? {};
      const thumbnails = snippet.thumbnails ?? {};
      const thumbUrl =
        thumbnails.high?.url ??
        thumbnails.medium?.url ??
        thumbnails.default?.url ??
        `https://img.youtube.com/vi/${vid}/hqdefault.jpg`;

      searchSnippets[vid] = {
        title: sanitizeString(snippet.title, 200),
        channelTitle: sanitizeString(snippet.channelTitle, 100),
        channelId: sanitizeString(snippet.channelId, 50),
        publishedAt: sanitizeString(snippet.publishedAt, 30),
        thumbnailUrl: thumbUrl,
      };
    }
  } catch (err) {
    console.error("YouTube search fetch error:", err);
    return new Response(JSON.stringify({ error: "Watch is temporarily unavailable. Please try again later." }), {
      status: 503,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  if (videoIds.length === 0) {
    return new Response(JSON.stringify({ results: [], next_page_token: null }), {
      status: 200,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });
  }

  // ── Step 2: Videos API for duration ───────────────────────────────────────

  const durationMap: Record<string, string | undefined> = {};

  try {
    const videoParams = new URLSearchParams({
      part: "contentDetails",
      id: videoIds.join(","),
      key: YOUTUBE_API_KEY,
    });

    const videoRes = await fetch(
      `https://www.googleapis.com/youtube/v3/videos?${videoParams.toString()}`,
      { headers: { "Accept": "application/json" } }
    );

    if (videoRes.ok) {
      const videoData = await videoRes.json();
      for (const item of videoData.items ?? []) {
        const vid = item.id;
        const duration = item.contentDetails?.duration;
        if (vid && duration) {
          durationMap[vid] = formatDuration(duration);
        }
      }
    }
  } catch {
    // Duration enrichment is optional — continue without it
  }

  // ── Assemble sanitized results ─────────────────────────────────────────────

  const results: SearchResult[] = videoIds.map((vid) => {
    const snippet = searchSnippets[vid];
    return {
      video_id: vid,
      title: snippet?.title ?? "YouTube Video",
      thumbnail_url: snippet?.thumbnailUrl ?? `https://img.youtube.com/vi/${vid}/hqdefault.jpg`,
      channel_title: snippet?.channelTitle ?? "",
      channel_id: snippet?.channelId ?? "",
      published_at: snippet?.publishedAt ?? "",
      duration: durationMap[vid],
    };
  });

  // Update cache
  cache.set(cacheKey, { results, timestamp: Date.now() });

  // Evict old cache entries (keep cache from growing unbounded)
  if (cache.size > 500) {
    const now = Date.now();
    for (const [key, entry] of cache.entries()) {
      if (now - entry.timestamp > CACHE_TTL_MS * 2) {
        cache.delete(key);
      }
    }
  }

  return new Response(
    JSON.stringify({ results, next_page_token: nextPageToken ?? null }),
    {
      status: 200,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    }
  );
});
