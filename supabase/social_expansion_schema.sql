-- ==========================================================
-- Z CHAT: Social Expansion Schema (Profiles, Follows, Comments,
-- Saves, Moments, Views, Notifications & Complete RLS)
-- ==========================================================

-- 1. Extend profiles table with privacy, counts, and social fields
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS followers_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS following_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS post_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS avatar_object_key TEXT,
  ADD COLUMN IF NOT EXISTS banner_object_key TEXT;

-- 2. Follow Relationships Table
CREATE TABLE IF NOT EXISTS public.follow_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_follow_pair UNIQUE (follower_id, following_id),
  CONSTRAINT prevent_self_follow CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follow_follower ON public.follow_relationships(follower_id, status);
CREATE INDEX IF NOT EXISTS idx_follow_following ON public.follow_relationships(following_id, status);
CREATE INDEX IF NOT EXISTS idx_follow_status ON public.follow_relationships(status);

-- 3. Blocked Users Table
CREATE TABLE IF NOT EXISTS public.blocked_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_block_pair UNIQUE (blocker_id, blocked_id),
  CONSTRAINT prevent_self_block CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_blocked ON public.blocked_users(blocked_id);

-- 4. Extend Posts Table with comments_count
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS comments_count INT NOT NULL DEFAULT 0;

-- 5. Post Comments Table
CREATE TABLE IF NOT EXISTS public.post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON public.post_comments(user_id);

-- 6. Saved Posts Table (Private bookmarks)
CREATE TABLE IF NOT EXISTS public.saved_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_saved_post UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_posts_user_id ON public.saved_posts(user_id, created_at DESC);

-- 7. Moments Table (24-Hour Ephemeral Stories)
CREATE TABLE IF NOT EXISTS public.moments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  imagekit_file_id TEXT,
  media_url TEXT NOT NULL,
  thumbnail_url TEXT,
  caption TEXT,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'followers', 'private')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_moments_user_expires ON public.moments(user_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_moments_expires_at ON public.moments(expires_at DESC);

-- 8. Moment Views Table
CREATE TABLE IF NOT EXISTS public.moment_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  moment_id UUID NOT NULL REFERENCES public.moments(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_moment_view UNIQUE (moment_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS idx_moment_views_moment ON public.moment_views(moment_id, viewed_at DESC);

-- 9. Social Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('follow_request', 'follow_accept', 'new_follower', 'like', 'comment', 'share', 'mention')),
  entity_id UUID,
  content TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_id, created_at DESC);

-- ==========================================================
-- Triggers and Functions for Counters
-- ==========================================================

-- Trigger for followers & following counts
CREATE OR REPLACE FUNCTION public.update_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'accepted' THEN
    UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
      UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
      UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    ELSIF OLD.status = 'accepted' AND NEW.status = 'pending' THEN
      UPDATE public.profiles SET followers_count = GREATEST(followers_count - 1, 0) WHERE id = NEW.following_id;
      UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0) WHERE id = NEW.follower_id;
    END IF;
  ELSIF TG_OP = 'DELETE' AND OLD.status = 'accepted' THEN
    UPDATE public.profiles SET followers_count = GREATEST(followers_count - 1, 0) WHERE id = OLD.following_id;
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0) WHERE id = OLD.follower_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_follow_counts ON public.follow_relationships;
CREATE TRIGGER trigger_update_follow_counts
AFTER INSERT OR UPDATE OR DELETE ON public.follow_relationships
FOR EACH ROW EXECUTE FUNCTION public.update_follow_counts();

-- Trigger for post comments count
CREATE OR REPLACE FUNCTION public.update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_post_comment_count ON public.post_comments;
CREATE TRIGGER trigger_update_post_comment_count
AFTER INSERT OR DELETE ON public.post_comments
FOR EACH ROW EXECUTE FUNCTION public.update_post_comment_count();

-- RPC helpers for atomic post like increment/decrement
CREATE OR REPLACE FUNCTION public.increment_post_likes(p_post_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.posts SET like_count = like_count + 1 WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_post_likes(p_post_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================================

ALTER TABLE public.follow_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moment_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Follow relationships RLS
DROP POLICY IF EXISTS "Users can view relevant follow relationships" ON public.follow_relationships;
CREATE POLICY "Users can view relevant follow relationships"
  ON public.follow_relationships FOR SELECT
  USING (
    status = 'accepted'
    OR follower_id = auth.uid()
    OR following_id = auth.uid()
  );

DROP POLICY IF EXISTS "Users can initiate follows" ON public.follow_relationships;
CREATE POLICY "Users can initiate follows"
  ON public.follow_relationships FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS "Users can update follows for their own account" ON public.follow_relationships;
CREATE POLICY "Users can update follows for their own account"
  ON public.follow_relationships FOR UPDATE
  USING (auth.uid() = following_id OR auth.uid() = follower_id);

DROP POLICY IF EXISTS "Users can delete follows" ON public.follow_relationships;
CREATE POLICY "Users can delete follows"
  ON public.follow_relationships FOR DELETE
  USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- Blocked users RLS
DROP POLICY IF EXISTS "Users can manage own blocks" ON public.blocked_users;
CREATE POLICY "Users can manage own blocks"
  ON public.blocked_users FOR ALL
  USING (auth.uid() = blocker_id)
  WITH CHECK (auth.uid() = blocker_id);

-- Comments RLS
DROP POLICY IF EXISTS "Comments viewable by everyone who can see post" ON public.post_comments;
CREATE POLICY "Comments viewable by everyone who can see post"
  ON public.post_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.posts p
      JOIN public.profiles pr ON pr.id = p.user_id
      WHERE p.id = post_comments.post_id
      AND (
        p.user_id = auth.uid()
        OR (
          pr.is_private = FALSE
          AND p.visibility = 'public'
        )
        OR EXISTS (
          SELECT 1 FROM public.follow_relationships fr
          WHERE fr.following_id = p.user_id
          AND fr.follower_id = auth.uid()
          AND fr.status = 'accepted'
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can insert comments" ON public.post_comments;
CREATE POLICY "Users can insert comments"
  ON public.post_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own comments or post owners can delete" ON public.post_comments;
CREATE POLICY "Users can delete own comments or post owners can delete"
  ON public.post_comments FOR DELETE
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id
      AND posts.user_id = auth.uid()
    )
  );

-- Saved posts RLS (Strict privacy: only the owner can see and manage)
DROP POLICY IF EXISTS "Users can view only their own saved posts" ON public.saved_posts;
CREATE POLICY "Users can view only their own saved posts"
  ON public.saved_posts FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can save posts" ON public.saved_posts;
CREATE POLICY "Users can save posts"
  ON public.saved_posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unsave posts" ON public.saved_posts;
CREATE POLICY "Users can unsave posts"
  ON public.saved_posts FOR DELETE
  USING (auth.uid() = user_id);

-- Moments RLS
DROP POLICY IF EXISTS "Users can view active moments" ON public.moments;
CREATE POLICY "Users can view active moments"
  ON public.moments FOR SELECT
  USING (
    expires_at > now()
    AND (
      user_id = auth.uid()
      OR (
        visibility = 'public'
        AND EXISTS (
          SELECT 1 FROM public.profiles pr
          WHERE pr.id = moments.user_id
          AND pr.is_private = FALSE
        )
      )
      OR EXISTS (
        SELECT 1 FROM public.follow_relationships fr
        WHERE fr.following_id = moments.user_id
        AND fr.follower_id = auth.uid()
        AND fr.status = 'accepted'
      )
    )
  );

DROP POLICY IF EXISTS "Users can insert own moments" ON public.moments;
CREATE POLICY "Users can insert own moments"
  ON public.moments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own moments" ON public.moments;
CREATE POLICY "Users can delete own moments"
  ON public.moments FOR DELETE
  USING (auth.uid() = user_id);

-- Moment Views RLS
DROP POLICY IF EXISTS "Moment owners and viewers can see views" ON public.moment_views;
CREATE POLICY "Moment owners and viewers can see views"
  ON public.moment_views FOR SELECT
  USING (
    viewer_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.moments m
      WHERE m.id = moment_views.moment_id
      AND m.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can record own moment view" ON public.moment_views;
CREATE POLICY "Users can record own moment view"
  ON public.moment_views FOR INSERT
  WITH CHECK (auth.uid() = viewer_id);

-- Notifications RLS
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = recipient_id);

DROP POLICY IF EXISTS "System and authenticated users can insert notifications" ON public.notifications;
CREATE POLICY "System and authenticated users can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() = sender_id);
