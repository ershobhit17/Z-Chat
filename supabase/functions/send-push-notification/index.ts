// send-push-notification/index.ts
// Push notification dispatcher for Z Chat via Firebase Cloud Messaging (FCM HTTP v1 & Legacy).
// Can be invoked:
// 1. Via Supabase Database Webhook (on messages INSERT)
// 2. Directly via Supabase client (supabase.functions.invoke('send-push-notification'))

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function corsHeaders(origin: string) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

interface PushPayload {
  conversation_id: string;
  sender_id: string;
  message_id?: string;
  content?: string;
  message_type?: string;
}

// ─── WebCrypto Helpers for Google OAuth2 / FCM HTTP v1 ────────────────────────

function pemToBinary(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binaryString = atob(b64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function base64Url(data: Uint8Array | string): string {
  let b64: string;
  if (typeof data === "string") {
    b64 = btoa(data);
  } else {
    let str = "";
    for (let i = 0; i < data.length; i++) str += String.fromCharCode(data[i]);
    b64 = btoa(str);
  }
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cachedOAuthToken: { token: string; expiresAt: number } | null = null;

async function getGoogleOAuth2Token(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedOAuthToken && cachedOAuthToken.expiresAt > now + 60) {
    return cachedOAuthToken.token;
  }

  const binaryDer = pemToBinary(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encHeader = base64Url(JSON.stringify(header));
  const encPayload = base64Url(JSON.stringify(payload));
  const unsignedJwt = `${encHeader}.${encPayload}`;

  const sigBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt)
  );
  const signedJwt = `${unsignedJwt}.${base64Url(new Uint8Array(sigBuffer))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const data = await res.json();
  if (!data.access_token) {
    throw new Error(`Google OAuth2 token exchange failed: ${JSON.stringify(data)}`);
  }

  cachedOAuthToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };

  return data.access_token;
}

// ─── Main Dispatcher ──────────────────────────────────────────────────────────

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

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
  const firebaseServiceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({ error: "Supabase service configuration missing" }),
      { status: 500, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const body = await req.json();

    // Support both direct invocation and Supabase Database Webhook format
    let data: PushPayload;
    if (body.record) {
      data = {
        conversation_id: body.record.conversation_id,
        sender_id: body.record.sender_id,
        message_id: body.record.id,
        content: body.record.content,
        message_type: body.record.message_type,
      };
    } else {
      data = body as PushPayload;
    }

    if (!data.conversation_id || !data.sender_id) {
      return new Response(
        JSON.stringify({ error: "conversation_id and sender_id are required" }),
        { status: 400, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch sender profile
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("display_name, username, avatar_url")
      .eq("id", data.sender_id)
      .maybeSingle();

    const senderName = senderProfile?.display_name || senderProfile?.username || "Someone";

    // 2. Fetch conversation members excluding the sender
    const { data: members, error: membersError } = await supabase
      .from("conversation_members")
      .select("user_id")
      .eq("conversation_id", data.conversation_id)
      .neq("user_id", data.sender_id);

    if (membersError || !members || members.length === 0) {
      return new Response(
        JSON.stringify({ message: "No recipients to notify" }),
        { status: 200, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
      );
    }

    const recipientIds = members.map((m: { user_id: string }) => m.user_id);

    // 3. Filter out blocks (both directions)
    const { data: blocks } = await supabase
      .from("blocked_users")
      .select("blocker_id, blocked_id")
      .or(
        `and(blocker_id.eq.${data.sender_id},blocked_id.in.(${recipientIds.join(",")})),and(blocked_id.eq.${data.sender_id},blocker_id.in.(${recipientIds.join(",")}))`
      );

    const blockedUserIds = new Set<string>();
    if (blocks) {
      for (const b of blocks) {
        if (b.blocker_id === data.sender_id) blockedUserIds.add(b.blocked_id);
        if (b.blocked_id === data.sender_id) blockedUserIds.add(b.blocker_id);
      }
    }

    const eligibleRecipientIds = recipientIds.filter((id: string) => !blockedUserIds.has(id));
    if (eligibleRecipientIds.length === 0) {
      return new Response(
        JSON.stringify({ message: "All recipients filtered by blocks" }),
        { status: 200, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
      );
    }

    // 4. Fetch FCM tokens for eligible recipients
    const { data: recipientProfiles, error: profilesError } = await supabase
      .from("profiles")
      .select("id, fcm_token")
      .in("id", eligibleRecipientIds)
      .not("fcm_token", "is", null);

    if (profilesError || !recipientProfiles || recipientProfiles.length === 0) {
      return new Response(
        JSON.stringify({ message: "No active FCM tokens found for recipients" }),
        { status: 200, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
      );
    }

    // 5. Format notification body
    let displayBody = data.content ?? "";
    if (!displayBody) {
      switch (data.message_type) {
        case "image":
          displayBody = "📷 Sent an image";
          break;
        case "video":
          displayBody = "🎥 Sent a video";
          break;
        case "audio":
          displayBody = "🎵 Sent a voice message";
          break;
        case "shared_post":
          displayBody = "📌 Shared a post";
          break;
        case "youtube":
          displayBody = "▶️ Shared a YouTube video";
          break;
        default:
          displayBody = "Sent a message";
      }
    }

    // 6. Send push notifications
    const tokens = recipientProfiles
      .map((p: { fcm_token: string }) => p.fcm_token)
      .filter((t: string) => t && t.length > 10);

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No valid tokens to send" }),
        { status: 200, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
      );
    }

    let sentCount = 0;
    const invalidTokens: string[] = [];

    // Prioritize modern FCM HTTP v1 using Service Account
    if (firebaseServiceAccountRaw) {
      try {
        const sa = typeof firebaseServiceAccountRaw === "string"
          ? JSON.parse(firebaseServiceAccountRaw)
          : firebaseServiceAccountRaw;

        const accessToken = await getGoogleOAuth2Token(sa);
        const projectId = sa.project_id;

        for (const token of tokens) {
          try {
            const fcmRes = await fetch(
              `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
              {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  Authorization: `Bearer ${accessToken}`,
                },
                body: JSON.stringify({
                  message: {
                    token: token,
                    notification: {
                      title: senderName,
                      body: displayBody,
                    },
                    data: {
                      conversation_id: data.conversation_id,
                      sender_id: data.sender_id,
                      message_id: data.message_id || "",
                      click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    android: {
                      priority: "high",
                      notification: {
                        sound: "default",
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                      },
                    },
                    apns: {
                      payload: {
                        aps: {
                          sound: "default",
                          badge: 1,
                        },
                      },
                    },
                  },
                }),
              }
            );

            if (fcmRes.ok) {
              sentCount++;
            } else {
              const errData = await fcmRes.json();
              console.warn("FCM v1 dispatch returned error:", errData);
              const errorCode = errData?.error?.details?.[0]?.errorCode || errData?.error?.status;
              if (
                errorCode === "UNREGISTERED" ||
                errorCode === "INVALID_ARGUMENT" ||
                errData?.error?.message?.includes("not a valid FCM registration token")
              ) {
                invalidTokens.push(token);
              }
            }
          } catch (e) {
            console.error("FCM v1 send error for token:", e);
          }
        }
      } catch (saErr) {
        console.error("Failed to process FCM HTTP v1:", saErr);
      }
    } else if (fcmServerKey) {
      // Legacy fallback
      for (const token of tokens) {
        try {
          const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `key=${fcmServerKey}`,
            },
            body: JSON.stringify({
              to: token,
              notification: {
                title: senderName,
                body: displayBody,
                sound: "default",
              },
              data: {
                conversation_id: data.conversation_id,
                sender_id: data.sender_id,
                message_id: data.message_id || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              priority: "high",
            }),
          });

          const result = await fcmRes.json();
          if (result.success === 1) {
            sentCount++;
          } else if (
            result.results?.[0]?.error === "NotRegistered" ||
            result.results?.[0]?.error === "InvalidRegistration"
          ) {
            invalidTokens.push(token);
          }
        } catch (e) {
          console.error("FCM legacy send failed for token:", e);
        }
      }
    }

    // Clean up invalid/stale tokens from profiles table
    if (invalidTokens.length > 0) {
      await supabase
        .from("profiles")
        .update({ fcm_token: null, fcm_token_updated_at: new Date().toISOString() })
        .in("fcm_token", invalidTokens);
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: sentCount,
        recipients: recipientProfiles.length,
        invalid_tokens_removed: invalidTokens.length,
      }),
      { status: 200, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("send-push-notification error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Internal server error" }),
      { status: 500, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } }
    );
  }
});
