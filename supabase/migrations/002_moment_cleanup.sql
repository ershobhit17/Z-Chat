-- ==============================================================================
-- Z CHAT — Moment Cleanup Migration 002
-- Schedules automatic deletion of expired moments via pg_cron.
-- Run AFTER 001_production_hardening.sql
-- ==============================================================================

-- ==============================================================================
-- Option A: pg_cron (requires pg_cron extension — Pro plan and above)
-- If pg_cron is not enabled, use Option B (scheduled Edge Function).
-- ==============================================================================

DO $$
BEGIN
  -- Only schedule if pg_cron is available
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Delete expired moments every 30 minutes
    -- This runs server-side, not through the app.
    PERFORM cron.schedule(
      'delete-expired-moments',      -- job name
      '*/30 * * * *',                -- every 30 minutes
      $$
        DELETE FROM public.moments
        WHERE expires_at < now()
          AND expires_at > now() - interval '25 hours'; -- Safety: only delete recently expired
      $$
    );

    RAISE NOTICE 'pg_cron job scheduled: delete-expired-moments every 30 minutes';
  ELSE
    RAISE NOTICE 'pg_cron not available. Use Supabase Edge Function scheduled cron instead (see below).';
  END IF;
END $$;

-- ==============================================================================
-- Option B: If pg_cron is NOT available, deploy this Edge Function and 
-- configure it in Supabase Dashboard → Edge Functions → Schedules:
--   Function: cleanup-moments
--   Schedule: every 30 minutes (*/30 * * * *)
--
-- The Edge Function code is at: supabase/functions/cleanup-moments/index.ts
-- ==============================================================================

-- Helper function to clean up expired moments (can be called manually too)
CREATE OR REPLACE FUNCTION public.cleanup_expired_moments()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INT;
BEGIN
  WITH deleted AS (
    DELETE FROM public.moments
    WHERE expires_at < now()
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_count FROM deleted;

  RETURN deleted_count;
END;
$$;

-- Grant execute to service role only (not anon/authenticated)
REVOKE ALL ON FUNCTION public.cleanup_expired_moments() FROM public;
REVOKE ALL ON FUNCTION public.cleanup_expired_moments() FROM anon;
REVOKE ALL ON FUNCTION public.cleanup_expired_moments() FROM authenticated;
