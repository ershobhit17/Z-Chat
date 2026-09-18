-- ==========================================================
-- Z CHAT: Social Profiles & Posts Schema with RLS
-- ==========================================================

-- 1. Extend profiles table with social and R2 fields
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS avatar_object_key TEXT,
  ADD COLUMN IF NOT EXISTS banner_object_key TEXT,
  ADD COLUMN IF NOT EXISTS post_count INT DEFAULT 0;

-- 2. Create posts table
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  caption TEXT,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'private', 'followers')),
  like_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);

-- 3. Create post_media table
CREATE TABLE IF NOT EXISTS public.post_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  object_key TEXT NOT NULL,
  media_url TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  mime_type TEXT,
  file_size BIGINT,
  width INT,
  height INT,
  duration INT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_post_media_post_id ON public.post_media(post_id);

-- 4. Create post_likes table
CREATE TABLE IF NOT EXISTS public.post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);

-- 5. Enable Row Level Security
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for posts
DROP POLICY IF EXISTS "Public posts are viewable by everyone" ON public.posts;
CREATE POLICY "Public posts are viewable by everyone"
  ON public.posts FOR SELECT
  USING (visibility = 'public' OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own posts" ON public.posts;
CREATE POLICY "Users can insert their own posts"
  ON public.posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own posts" ON public.posts;
CREATE POLICY "Users can update their own posts"
  ON public.posts FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own posts" ON public.posts;
CREATE POLICY "Users can delete their own posts"
  ON public.posts FOR DELETE
  USING (auth.uid() = user_id);

-- 7. RLS Policies for post_media
DROP POLICY IF EXISTS "Media viewable if parent post viewable" ON public.post_media;
CREATE POLICY "Media viewable if parent post viewable"
  ON public.post_media FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_media.post_id
      AND (posts.visibility = 'public' OR posts.user_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can insert their own post media" ON public.post_media;
CREATE POLICY "Users can insert their own post media"
  ON public.post_media FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own post media" ON public.post_media;
CREATE POLICY "Users can delete their own post media"
  ON public.post_media FOR DELETE
  USING (auth.uid() = user_id);

-- 8. RLS Policies for post_likes
DROP POLICY IF EXISTS "Likes viewable by everyone" ON public.post_likes;
CREATE POLICY "Likes viewable by everyone"
  ON public.post_likes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can toggle own likes" ON public.post_likes;
CREATE POLICY "Users can toggle own likes"
  ON public.post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can remove own likes" ON public.post_likes;
CREATE POLICY "Users can remove own likes"
  ON public.post_likes FOR DELETE
  USING (auth.uid() = user_id);

-- 9. Trigger for post_count on profiles
CREATE OR REPLACE FUNCTION public.update_profile_post_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET post_count = COALESCE(post_count, 0) + 1 WHERE id = NEW.user_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET post_count = GREATEST(COALESCE(post_count, 0) - 1, 0) WHERE id = OLD.user_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_profile_post_count ON public.posts;
CREATE TRIGGER trigger_update_profile_post_count
AFTER INSERT OR DELETE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.update_profile_post_count();
