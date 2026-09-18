// Supabase Edge Function: Cloudflare R2 Storage Service
// Generates presigned URLs for client-side direct uploads & downloads without exposing credentials.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.370.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.370.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Authenticate user via Supabase
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized user" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Read R2 credentials from environment variables
    const accountId = Deno.env.get("R2_ACCOUNT_ID");
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
    const bucketName = Deno.env.get("R2_BUCKET_NAME") || "zchat-media";
    const publicDomain = Deno.env.get("R2_PUBLIC_DOMAIN"); // e.g. "https://pub-xxxx.r2.dev"

    if (!accountId || !accessKeyId || !secretAccessKey) {
      return new Response(
        JSON.stringify({
          error: "R2_NOT_CONFIGURED",
          message: "Cloudflare R2 credentials are not configured in edge function secrets.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Initialize S3 client for Cloudflare R2 endpoint
    const s3 = new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    const body = await req.json();
    const { action, objectKey, contentType, isPublic } = body;

    // Security validation: ensure the user can only manipulate their own path
    const expectedPrefix = `users/${user.id}/`;
    if (!objectKey || !objectKey.startsWith(expectedPrefix)) {
      return new Response(
        JSON.stringify({ error: `Forbidden: objectKey must start with '${expectedPrefix}'` }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (action === "get_upload_url") {
      const command = new PutObjectCommand({
        Bucket: bucketName,
        Key: objectKey,
        ContentType: contentType || "application/octet-stream",
      });

      // Presign URL for 15 minutes
      const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 900 });

      // Generate public URL if public domain is available
      const mediaUrl = publicDomain
        ? `${publicDomain.replace(/\/$/, "")}/${objectKey}`
        : uploadUrl.split("?")[0];

      return new Response(
        JSON.stringify({
          uploadUrl,
          mediaUrl,
          objectKey,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } else if (action === "get_download_url") {
      const command = new GetObjectCommand({
        Bucket: bucketName,
        Key: objectKey,
      });

      const downloadUrl = await getSignedUrl(s3, command, { expiresIn: 3600 });

      return new Response(
        JSON.stringify({
          downloadUrl,
          objectKey,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } else if (action === "delete_object") {
      const command = new DeleteObjectCommand({
        Bucket: bucketName,
        Key: objectKey,
      });

      await s3.send(command);

      return new Response(
        JSON.stringify({
          success: true,
          deletedKey: objectKey,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify({ error: "Invalid action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
