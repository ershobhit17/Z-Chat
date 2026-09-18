// Supabase Edge Function: fetch-link-preview
// Secure, SSRF-protected metadata fetcher for rich link previews in Z Chat.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

// SSRF Protection: Deny private, loopback, link-local, and cloud metadata IPs
function isPrivateHost(hostname: string): boolean {
  const lower = hostname.toLowerCase();
  if (
    lower === "localhost" ||
    lower.endsWith(".localhost") ||
    lower.endsWith(".local") ||
    lower.endsWith(".internal") ||
    lower === "127.0.0.1" ||
    lower === "0.0.0.0" ||
    lower === "::1" ||
    lower === "metadata.google.internal" ||
    lower === "169.254.169.254"
  ) {
    return true;
  }

  // Check IPv4 private ranges
  const ipParts = lower.split(".").map(Number);
  if (ipParts.length === 4 && ipParts.every((n) => !isNaN(n) && n >= 0 && n <= 255)) {
    // 10.0.0.0/8
    if (ipParts[0] === 10) return true;
    // 127.0.0.0/8
    if (ipParts[0] === 127) return true;
    // 172.16.0.0/12
    if (ipParts[0] === 172 && ipParts[1] >= 16 && ipParts[1] <= 31) return true;
    // 192.168.0.0/16
    if (ipParts[0] === 192 && ipParts[1] === 168) return true;
    // 169.254.0.0/16 (link-local / AWS / GCP metadata)
    if (ipParts[0] === 169 && ipParts[1] === 254) return true;
  }

  return false;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let urlToFetch = "";
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      urlToFetch = body.url || "";
    } else {
      const urlObj = new URL(req.url);
      urlToFetch = urlObj.searchParams.get("url") || "";
    }

    urlToFetch = urlToFetch.trim();
    if (!urlToFetch) {
      return new Response(JSON.stringify({ error: "Missing url parameter" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Ensure scheme
    if (!urlToFetch.startsWith("http://") && !urlToFetch.startsWith("https://")) {
      urlToFetch = "https://" + urlToFetch;
    }

    const parsed = new URL(urlToFetch);
    // Strict scheme validation: only http/https allowed
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return new Response(JSON.stringify({ error: "Invalid URL scheme. Only HTTP and HTTPS are permitted." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // SSRF Check
    if (isPrivateHost(parsed.hostname)) {
      return new Response(JSON.stringify({ error: "Access to private or local networks is denied." }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch with 4-second timeout & maximum size cap
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);

    const response = await fetch(urlToFetch, {
      signal: controller.signal,
      headers: {
        "User-Agent": "ZChatBot/1.0 (Mozilla/5.0 compatible; LinkPreviewBot)",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
      redirect: "follow",
    });
    clearTimeout(timeout);

    const contentType = response.headers.get("content-type") || "";
    if (!contentType.includes("text/html") && !contentType.includes("application/xhtml+xml")) {
      return new Response(
        JSON.stringify({
          success: true,
          url: urlToFetch,
          domain: parsed.hostname.replace(/^www\./, ""),
          title: parsed.hostname,
          description: "",
          image: null,
          siteName: parsed.hostname,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Read up to 250KB of HTML
    const reader = response.body?.getReader();
    let html = "";
    if (reader) {
      const decoder = new TextDecoder();
      let bytesRead = 0;
      while (bytesRead < 250000) {
        const { done, value } = await reader.read();
        if (done) break;
        bytesRead += value.byteLength;
        html += decoder.decode(value, { stream: true });
        if (html.includes("</head>")) break;
      }
      reader.cancel();
    }

    // Helper regex extractors
    const extractMeta = (propName: string): string => {
      const match1 = new RegExp(`<meta[^>]+(?:property|name)=["']${propName}["'][^>]+content=["']([^"']*)["']`, "i").exec(html);
      if (match1 && match1[1]) return match1[1].trim();
      const match2 = new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]+(?:property|name)=["']${propName}["']`, "i").exec(html);
      if (match2 && match2[1]) return match2[1].trim();
      return "";
    };

    const extractTitle = (): string => {
      const ogTitle = extractMeta("og:title") || extractMeta("twitter:title");
      if (ogTitle) return ogTitle;
      const titleMatch = /<title[^>]*>([^<]*)<\/title>/i.exec(html);
      if (titleMatch && titleMatch[1]) return titleMatch[1].trim();
      return parsed.hostname;
    };

    const extractDescription = (): string => {
      return (
        extractMeta("og:description") ||
        extractMeta("twitter:description") ||
        extractMeta("description")
      );
    };

    const extractImage = (): string | null => {
      let img = extractMeta("og:image") || extractMeta("twitter:image");
      if (img && !img.startsWith("http://") && !img.startsWith("https://")) {
        try {
          img = new URL(img, urlToFetch).href;
        } catch (_) {
          img = null;
        }
      }
      return img || null;
    };

    const siteName = extractMeta("og:site_name") || parsed.hostname.replace(/^www\./, "");
    const title = extractTitle();
    const description = extractDescription();
    const image = extractImage();

    return new Response(
      JSON.stringify({
        success: true,
        url: urlToFetch,
        domain: parsed.hostname.replace(/^www\./, ""),
        title: title || parsed.hostname,
        description: description,
        image: image,
        siteName: siteName,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        success: false,
        error: err.message || "Failed to fetch preview",
      }),
      {
        status: 200, // Graceful response
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
