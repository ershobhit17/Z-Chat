// cleanup-moments/index.ts
// Scheduled Edge Function to delete expired moments.
// If pg_cron is not available on your Supabase plan, schedule this function
// via: Supabase Dashboard → Edge Functions → cleanup-moments → Schedule → */30 * * * *

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (_req: Request) => {
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return new Response(JSON.stringify({ error: "Missing env vars" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

  try {
    // Call the DB function for atomic cleanup
    const { data, error } = await supabase.rpc("cleanup_expired_moments");

    if (error) {
      console.error("Moment cleanup error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const deletedCount = data as number ?? 0;
    console.log(`Moment cleanup: deleted ${deletedCount} expired moments`);

    return new Response(
      JSON.stringify({ success: true, deleted: deletedCount }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Unexpected cleanup error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
