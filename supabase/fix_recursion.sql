-- ============================================================================
-- Z CHAT — COMPREHENSIVE FIX SCRIPT
-- Run this in Supabase Dashboard -> SQL Editor -> Run
-- Fixes:
-- 1. Profiles RLS: Allows anyone (including anon / unauthenticated on login) to view profiles
-- 2. RLS Infinite Recursion: Fixes conversation_members and messages policies using SECURITY DEFINER
-- 3. Internal Email Sync: Ensures all users have email = username_lower@zchat.internal
-- 4. er_shobhit_ Password Reset: Guarantees password is set to 172531 with confirmed email
-- ============================================================================

-- 1. FIX PROFILES RLS (Fixes "User not found" and username search)
DROP POLICY IF EXISTS "Profiles are viewable by anyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by anyone" 
ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- 2. CREATE SECURITY DEFINER HELPER FUNCTION TO BREAK RECURSION
CREATE OR REPLACE FUNCTION public.is_conversation_member(_conversation_id UUID, _user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = _conversation_id AND user_id = _user_id
  );
$$;

-- 3. FIX CONVERSATION MEMBERS POLICIES
DROP POLICY IF EXISTS "Users can view members of their conversations" ON public.conversation_members;
CREATE POLICY "Users can view members of their conversations" 
ON public.conversation_members FOR SELECT TO authenticated 
USING (
    user_id = auth.uid() 
    OR public.is_conversation_member(conversation_id, auth.uid())
);

DROP POLICY IF EXISTS "Users can join or be added to conversations" ON public.conversation_members;
CREATE POLICY "Users can join or be added to conversations" 
ON public.conversation_members FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own membership settings" ON public.conversation_members;
CREATE POLICY "Users can update their own membership settings" 
ON public.conversation_members FOR UPDATE TO authenticated 
USING (user_id = auth.uid());

-- 4. FIX CONVERSATIONS POLICIES
DROP POLICY IF EXISTS "Users can view conversations they belong to" ON public.conversations;
CREATE POLICY "Users can view conversations they belong to" 
ON public.conversations FOR SELECT TO authenticated 
USING (
    public.is_conversation_member(id, auth.uid())
);

DROP POLICY IF EXISTS "Authenticated users can create conversations" ON public.conversations;
CREATE POLICY "Authenticated users can create conversations" 
ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);

-- 5. FIX MESSAGES POLICIES
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations" 
ON public.messages FOR SELECT TO authenticated 
USING (
    public.is_conversation_member(conversation_id, auth.uid())
);

DROP POLICY IF EXISTS "Users can insert messages into their conversations" ON public.messages;
CREATE POLICY "Users can insert messages into their conversations" 
ON public.messages FOR INSERT TO authenticated 
WITH CHECK (
    auth.uid() = sender_id 
    AND public.is_conversation_member(conversation_id, auth.uid())
);

DROP POLICY IF EXISTS "Senders can update their messages" ON public.messages;
CREATE POLICY "Senders can update their messages" 
ON public.messages FOR UPDATE TO authenticated 
USING (
    auth.uid() = sender_id 
    OR public.is_conversation_member(conversation_id, auth.uid())
);

-- 6. FIX ATTACHMENTS AND REACTIONS
DROP POLICY IF EXISTS "Users can view attachments of their conversations" ON public.message_attachments;
CREATE POLICY "Users can view attachments of their conversations" 
ON public.message_attachments FOR SELECT TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        WHERE m.id = message_attachments.message_id 
        AND public.is_conversation_member(m.conversation_id, auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can insert attachments" ON public.message_attachments;
CREATE POLICY "Users can insert attachments" 
ON public.message_attachments FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Users can view reactions in their conversations" ON public.message_reactions;
CREATE POLICY "Users can view reactions in their conversations" 
ON public.message_reactions FOR SELECT TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        WHERE m.id = message_reactions.message_id
        AND public.is_conversation_member(m.conversation_id, auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can insert/delete their own reactions" ON public.message_reactions;
CREATE POLICY "Users can insert/delete their own reactions" 
ON public.message_reactions FOR ALL TO authenticated 
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 7. SYNCHRONIZE INTERNAL EMAILS IN AUTH.USERS
-- Ensures every account's auth email is strictly username_lower@zchat.internal
UPDATE auth.users u
SET email = p.username_lower || '@zchat.internal',
    email_confirmed_at = COALESCE(u.email_confirmed_at, now())
FROM public.profiles p
WHERE u.id = p.id
  AND (u.email IS NULL OR u.email NOT LIKE '%@zchat.internal');

-- 8. RESET PASSWORD FOR er_shobhit_ TO 172531
-- Guarantees the password from the screenshot logs in immediately
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

UPDATE auth.users 
SET encrypted_password = crypt('172531', gen_salt('bf')),
    email_confirmed_at = COALESCE(email_confirmed_at, now()),
    email = 'er_shobhit_@zchat.internal'
WHERE id IN (
    SELECT id FROM public.profiles WHERE username_lower = 'er_shobhit_'
);

-- 9. ENSURE POSTGREST FOREIGN KEY BETWEEN conversation_members AND profiles
ALTER TABLE public.conversation_members
DROP CONSTRAINT IF EXISTS fk_conversation_members_profiles;

ALTER TABLE public.conversation_members
ADD CONSTRAINT fk_conversation_members_profiles
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 10. SAVED THEMES TABLE (Customization Studio)
CREATE TABLE IF NOT EXISTS public.saved_themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    theme_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.saved_themes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their saved themes" ON public.saved_themes;
CREATE POLICY "Users can manage their saved themes" 
ON public.saved_themes FOR ALL TO authenticated 
USING (user_id = auth.uid()) 
WITH CHECK (user_id = auth.uid());

-- 11. STORAGE BUCKET: chat_wallpapers
INSERT INTO storage.buckets (id, name, public) 
VALUES ('chat_wallpapers', 'chat_wallpapers', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Authenticated users can upload wallpapers" ON storage.objects;
CREATE POLICY "Authenticated users can upload wallpapers" 
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'chat_wallpapers');

DROP POLICY IF EXISTS "Wallpapers are viewable by anyone" ON storage.objects;
CREATE POLICY "Wallpapers are viewable by anyone" 
ON storage.objects FOR SELECT TO authenticated, anon 
USING (bucket_id = 'chat_wallpapers');


