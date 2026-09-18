-- ==============================================================================
-- Z CHAT — Production Hardening Migration 001
-- Run this against: nmjdkxviodpnnconlygg
-- ==============================================================================

-- ==============================================================================
-- 1. FIX messages.message_type CONSTRAINT
--    Root cause: shared_post and youtube were not in the allowed list,
--    causing ALL post/clip sharing to fail with a constraint violation.
-- ==============================================================================

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_message_type_check;

ALTER TABLE public.messages
  ADD CONSTRAINT messages_message_type_check
  CHECK (message_type IN ('text', 'image', 'video', 'audio', 'file', 'system', 'shared_post', 'youtube'));

-- Add status column to messages if missing (for sent/read tracking)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'sent'
  CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed'));

-- ==============================================================================
-- 2. ADD thumbnail_url TO post_media
--    Required for video thumbnail display in feed, profile grid, share cards.
-- ==============================================================================

ALTER TABLE public.post_media
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- ==============================================================================
-- 3. FIX moments.expires_at DEFAULT to 12 HOURS (was 24 hours)
-- ==============================================================================

ALTER TABLE public.moments
  ALTER COLUMN expires_at SET DEFAULT (now() + interval '12 hours');

-- ==============================================================================
-- 4. ADD fcm_token TO profiles
-- ==============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ;

-- ==============================================================================
-- 5. ADD moderation_state TO profiles
-- ==============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS moderation_state TEXT NOT NULL DEFAULT 'normal'
  CHECK (moderation_state IN ('normal', 'flagged', 'restricted', 'suspended', 'banned'));

-- ==============================================================================
-- 6. GENERALIZE reports TABLE
-- ==============================================================================

ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS target_type TEXT CHECK (target_type IN ('user', 'post', 'comment', 'moment')),
  ADD COLUMN IF NOT EXISTS target_id UUID,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID;

CREATE INDEX IF NOT EXISTS idx_reports_target ON public.reports(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON public.reports(reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);

-- ==============================================================================
-- 7. CREATE moderation_stats TABLE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.moderation_stats (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  report_count INT NOT NULL DEFAULT 0,
  unique_reporters INT NOT NULL DEFAULT 0,
  last_report_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.moderation_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own moderation stats" ON public.moderation_stats;
CREATE POLICY "Users can view own moderation stats"
  ON public.moderation_stats FOR SELECT
  USING (auth.uid() = user_id);

-- ==============================================================================
-- 8. CREATE moderation_events TABLE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.moderation_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment', 'moment', 'message', 'profile')),
  target_id UUID NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  provider TEXT NOT NULL DEFAULT 'sightengine',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'allowed', 'blocked', 'review')),
  category TEXT,
  score NUMERIC(5, 4),
  raw_reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_moderation_events_target ON public.moderation_events(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_moderation_events_user ON public.moderation_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_moderation_events_status ON public.moderation_events(status);

ALTER TABLE public.moderation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "No direct user access to moderation events" ON public.moderation_events;
CREATE POLICY "No direct user access to moderation events"
  ON public.moderation_events FOR ALL
  USING (false);

-- ==============================================================================
-- 9. CREATE app_config TABLE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.app_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'all')),
  latest_version TEXT NOT NULL DEFAULT '1.0.0',
  minimum_supported_version TEXT NOT NULL DEFAULT '1.0.0',
  update_required BOOLEAN NOT NULL DEFAULT false,
  update_message TEXT DEFAULT 'A new version of Z Chat is available.',
  store_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(platform)
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read app config" ON public.app_config;
CREATE POLICY "Anyone can read app config"
  ON public.app_config FOR SELECT
  USING (true);

INSERT INTO public.app_config (platform, latest_version, minimum_supported_version, update_required, update_message, store_url)
VALUES
  ('android', '1.0.0', '1.0.0', false, 'A new version of Z Chat is available. Update for the best experience.', 'https://play.google.com/store/apps/details?id=com.zchat.app'),
  ('ios', '1.0.0', '1.0.0', false, 'A new version of Z Chat is available. Update for the best experience.', 'https://apps.apple.com/app/zchat/id0000000000'),
  ('web', '1.0.0', '1.0.0', false, 'Please refresh for the latest version.', null)
ON CONFLICT (platform) DO NOTHING;

-- ==============================================================================
-- 10. FIX RLS ON posts TABLE — enforce private account + followers visibility
-- ==============================================================================

DROP POLICY IF EXISTS "Public posts are viewable by everyone" ON public.posts;
CREATE POLICY "Public posts are viewable by everyone"
  ON public.posts FOR SELECT
  USING (
    auth.uid() = user_id
    OR (
      visibility = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM public.profiles pr
        WHERE pr.id = posts.user_id AND pr.is_private = true
      )
    )
    OR (
      visibility IN ('public', 'followers')
      AND EXISTS (
        SELECT 1 FROM public.profiles pr
        WHERE pr.id = posts.user_id AND pr.is_private = true
      )
      AND EXISTS (
        SELECT 1 FROM public.follow_relationships fr
        WHERE fr.follower_id = auth.uid()
          AND fr.following_id = posts.user_id
          AND fr.status = 'accepted'
      )
    )
    OR (
      visibility = 'followers'
      AND NOT EXISTS (
        SELECT 1 FROM public.profiles pr
        WHERE pr.id = posts.user_id AND pr.is_private = true
      )
      AND EXISTS (
        SELECT 1 FROM public.follow_relationships fr
        WHERE fr.follower_id = auth.uid()
          AND fr.following_id = posts.user_id
          AND fr.status = 'accepted'
      )
    )
  );

DROP POLICY IF EXISTS "Media viewable if parent post viewable" ON public.post_media;
CREATE POLICY "Media viewable if parent post viewable"
  ON public.post_media FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_media.post_id
        AND (
          p.user_id = auth.uid()
          OR (
            p.visibility = 'public'
            AND NOT EXISTS (
              SELECT 1 FROM public.profiles pr WHERE pr.id = p.user_id AND pr.is_private = true
            )
          )
          OR EXISTS (
            SELECT 1 FROM public.follow_relationships fr
            WHERE fr.follower_id = auth.uid()
              AND fr.following_id = p.user_id
              AND fr.status = 'accepted'
          )
        )
    )
  );

-- ==============================================================================
-- 11. MIGRATE user_blocks -> blocked_users (canonical table)
-- 11. CONSOLIDATE BLOCKED USERS
-- ==============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_blocks' AND table_schema = 'public') THEN
    INSERT INTO public.blocked_users (blocker_id, blocked_id, created_at)
    SELECT ub.blocker_id, ub.blocked_id, ub.created_at
    FROM public.user_blocks ub
    WHERE NOT EXISTS (
      SELECT 1 FROM public.blocked_users bu
      WHERE bu.blocker_id = ub.blocker_id AND bu.blocked_id = ub.blocked_id
    );
  END IF;
END $$;

-- ==============================================================================
-- 12. ADD MISSING PERFORMANCE INDEXES
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_messages_conv_created_desc
  ON public.messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_sender
  ON public.messages(sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_read
  ON public.notifications(recipient_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_posts_visibility_created
  ON public.posts(visibility, created_at DESC) WHERE visibility = 'public';

CREATE INDEX IF NOT EXISTS idx_post_media_type
  ON public.post_media(media_type, post_id);

CREATE INDEX IF NOT EXISTS idx_follow_follower_accepted
  ON public.follow_relationships(follower_id, status) WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS idx_reports_created
  ON public.reports(created_at DESC);

-- ==============================================================================
-- 13. ATOMIC REPORT SUBMISSION WITH DEDUPLICATION
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.submit_report(
  p_reporter_id UUID,
  p_target_type TEXT,
  p_target_id UUID,
  p_reported_user_id UUID,
  p_reason TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_report UUID;
  v_report_id UUID;
  v_unique_reporters INT := 0;
  v_moderation_state TEXT := 'normal';
BEGIN
  IF p_reporter_id = p_reported_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot report yourself');
  END IF;

  SELECT id INTO v_existing_report
  FROM public.reports
  WHERE reporter_id = p_reporter_id
    AND target_type = p_target_type
    AND target_id = p_target_id
  LIMIT 1;

  IF v_existing_report IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already reported');
  END IF;

  v_report_id := gen_random_uuid();
  INSERT INTO public.reports (
    id, reporter_id, reported_user_id, target_type, target_id, reason, description, status
  ) VALUES (
    v_report_id, p_reporter_id, p_reported_user_id, p_target_type, p_target_id, p_reason, p_description, 'pending'
  );

  IF p_reported_user_id IS NOT NULL THEN
    INSERT INTO public.moderation_stats (user_id, report_count, unique_reporters, last_report_at)
    VALUES (p_reported_user_id, 1, 1, now())
    ON CONFLICT (user_id) DO UPDATE SET
      report_count = moderation_stats.report_count + 1,
      unique_reporters = (
        SELECT COUNT(DISTINCT reporter_id) FROM public.reports
        WHERE reported_user_id = p_reported_user_id AND status != 'dismissed'
      ),
      last_report_at = now(),
      updated_at = now();

    SELECT unique_reporters INTO v_unique_reporters
    FROM public.moderation_stats WHERE user_id = p_reported_user_id;

    SELECT moderation_state INTO v_moderation_state
    FROM public.profiles WHERE id = p_reported_user_id;

    IF v_unique_reporters >= 5 AND v_moderation_state = 'normal' THEN
      UPDATE public.profiles SET moderation_state = 'flagged' WHERE id = p_reported_user_id;
      v_moderation_state := 'flagged';
    END IF;

    IF v_unique_reporters >= 15 AND v_moderation_state IN ('normal', 'flagged') THEN
      UPDATE public.profiles SET moderation_state = 'restricted' WHERE id = p_reported_user_id;
      v_moderation_state := 'restricted';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'report_id', v_report_id,
    'unique_reporters', v_unique_reporters
  );
END;
$$;

-- ==============================================================================
-- 14. FCM TOKEN UPDATE HELPER
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.update_fcm_token(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = p_token, fcm_token_updated_at = now()
  WHERE id = auth.uid();
END;
$$;

-- ==============================================================================
-- 15. Add to realtime publication
-- ==============================================================================

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  EXCEPTION WHEN others THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.moments;
  EXCEPTION WHEN others THEN NULL;
  END;
END $$;
