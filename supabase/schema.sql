-- ==============================================================================
-- Z CHAT — SUPABASE DATABASE SCHEMA, RLS POLICIES & REALTIME SETUP
-- Project ID: nmjdkxviodpnnconlygg
-- ==============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. TABLES DEFINITIONS
-- ==============================================================================

-- 2.1 PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    username_lower TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT DEFAULT '',
    status TEXT DEFAULT 'Hey there! I am using Z Chat.',
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for case-insensitive username searching
CREATE INDEX IF NOT EXISTS idx_profiles_username_lower ON public.profiles(username_lower);

-- 2.2 CONVERSATIONS TABLE
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL DEFAULT 'direct' CHECK (type IN ('direct', 'group')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.3 CONVERSATION MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.conversation_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT now(),
    last_read_message_id UUID,
    is_muted BOOLEAN DEFAULT false,
    is_archived BOOLEAN DEFAULT false,
    is_pinned BOOLEAN DEFAULT false,
    chat_theme JSONB DEFAULT NULL,
    chat_wallpaper TEXT DEFAULT NULL,
    UNIQUE(conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_members_user ON public.conversation_members(user_id);
CREATE INDEX IF NOT EXISTS idx_conv_members_conv ON public.conversation_members(conversation_id);

-- 2.4 MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'file', 'system')),
    content TEXT,
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    is_edited BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    deleted_for UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON public.messages(conversation_id, created_at ASC);

-- 2.5 MESSAGE ATTACHMENTS TABLE
CREATE TABLE IF NOT EXISTS public.message_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    mime_type TEXT,
    file_size BIGINT,
    duration INT,
    width INT,
    height INT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attachments_msg ON public.message_attachments(message_id);

-- 2.6 MESSAGE REACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(message_id, user_id, reaction)
);

CREATE INDEX IF NOT EXISTS idx_reactions_msg ON public.message_reactions(message_id);

-- 2.7 USER SETTINGS (Appearance Studio & Preferences)
CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    theme_id TEXT DEFAULT 'midnight',
    custom_theme JSONB DEFAULT '{}',
    font_family TEXT DEFAULT 'Inter',
    font_size TEXT DEFAULT 'medium',
    bubble_style TEXT DEFAULT 'rounded',
    bubble_radius NUMERIC DEFAULT 16,
    bubble_sent_color TEXT DEFAULT '#7C5CFF',
    bubble_received_color TEXT DEFAULT '#1E1E28',
    bubble_sent_text_color TEXT DEFAULT '#FFFFFF',
    bubble_received_text_color TEXT DEFAULT '#FFFFFF',
    chat_background_type TEXT DEFAULT 'solid',
    chat_background_value TEXT DEFAULT '#0B0B0F',
    chat_density TEXT DEFAULT 'comfortable',
    show_avatars BOOLEAN DEFAULT true,
    show_timestamps BOOLEAN DEFAULT true,
    notification_style TEXT DEFAULT 'floating_card',
    notification_preview BOOLEAN DEFAULT true,
    sound_enabled BOOLEAN DEFAULT true,
    vibration_enabled BOOLEAN DEFAULT true,
    privacy_online_status BOOLEAN DEFAULT true,
    privacy_last_seen BOOLEAN DEFAULT true,
    privacy_read_receipts BOOLEAN DEFAULT true,
    privacy_typing_indicator BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.8 USER BLOCKS TABLE
CREATE TABLE IF NOT EXISTS public.user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(blocker_id, blocked_id)
);

-- 2.9 USER REPORTS TABLE
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- 3.1 PROFILES POLICIES
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by anyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by anyone" 
ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Helper function to break RLS recursion
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

-- 3.2 CONVERSATIONS POLICIES
DROP POLICY IF EXISTS "Users can view conversations they belong to" ON public.conversations;
CREATE POLICY "Users can view conversations they belong to" 
ON public.conversations FOR SELECT TO authenticated 
USING (
    public.is_conversation_member(id, auth.uid())
);

DROP POLICY IF EXISTS "Authenticated users can create conversations" ON public.conversations;
CREATE POLICY "Authenticated users can create conversations" 
ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);

-- 3.3 CONVERSATION MEMBERS POLICIES
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

-- 3.4 MESSAGES POLICIES
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

-- 3.5 MESSAGE ATTACHMENTS POLICIES
DROP POLICY IF EXISTS "Users can view attachments of their conversations" ON public.message_attachments;
CREATE POLICY "Users can view attachments of their conversations" 
ON public.message_attachments FOR SELECT TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.conversation_members cm ON cm.conversation_id = m.conversation_id
        WHERE m.id = message_attachments.message_id 
        AND cm.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Users can insert attachments" ON public.message_attachments;
CREATE POLICY "Users can insert attachments" 
ON public.message_attachments FOR INSERT TO authenticated WITH CHECK (true);

-- 3.6 MESSAGE REACTIONS POLICIES
DROP POLICY IF EXISTS "Users can view reactions in their conversations" ON public.message_reactions;
CREATE POLICY "Users can view reactions in their conversations" 
ON public.message_reactions FOR SELECT TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.conversation_members cm ON cm.conversation_id = m.conversation_id
        WHERE m.id = message_reactions.message_id 
        AND cm.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Users can insert/delete their own reactions" ON public.message_reactions;
CREATE POLICY "Users can insert/delete their own reactions" 
ON public.message_reactions FOR ALL TO authenticated 
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 3.7 USER SETTINGS POLICIES
DROP POLICY IF EXISTS "Users can manage their own settings" ON public.user_settings;
CREATE POLICY "Users can manage their own settings" 
ON public.user_settings FOR ALL TO authenticated 
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 3.8 USER BLOCKS POLICIES
DROP POLICY IF EXISTS "Users can manage their own blocks" ON public.user_blocks;
CREATE POLICY "Users can manage their own blocks" 
ON public.user_blocks FOR ALL TO authenticated 
USING (blocker_id = auth.uid())
WITH CHECK (blocker_id = auth.uid());

-- 3.9 REPORTS POLICIES
DROP POLICY IF EXISTS "Users can insert reports" ON public.reports;
CREATE POLICY "Users can insert reports" 
ON public.reports FOR INSERT TO authenticated 
WITH CHECK (reporter_id = auth.uid());

-- ==============================================================================
-- 4. FUNCTIONS & TRIGGERS
-- ==============================================================================

-- 4.1 Trigger to create profile and settings on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    raw_username TEXT;
    raw_display_name TEXT;
BEGIN
    raw_username := COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
    raw_display_name := COALESCE(new.raw_user_meta_data->>'display_name', raw_username);

    -- Insert profile
    INSERT INTO public.profiles (id, username, username_lower, display_name, avatar_url)
    VALUES (
        new.id,
        raw_username,
        lower(raw_username),
        raw_display_name,
        COALESCE(new.raw_user_meta_data->>'avatar_url', '')
    )
    ON CONFLICT (id) DO UPDATE 
    SET username = EXCLUDED.username,
        username_lower = EXCLUDED.username_lower,
        display_name = EXCLUDED.display_name;

    -- Insert default user settings
    INSERT INTO public.user_settings (user_id)
    VALUES (new.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 4.2 Helper function: Get or create direct conversation atomically
CREATE OR REPLACE FUNCTION public.get_or_create_direct_conversation(target_user_id UUID)
RETURNS UUID AS $$
DECLARE
    found_conv_id UUID;
    new_conv_id UUID;
    current_uid UUID;
BEGIN
    current_uid := auth.uid();
    IF current_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF current_uid = target_user_id THEN
        RAISE EXCEPTION 'Cannot start conversation with yourself';
    END IF;

    -- Look for existing 1-to-1 direct conversation
    SELECT cm1.conversation_id INTO found_conv_id
    FROM public.conversation_members cm1
    JOIN public.conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
    JOIN public.conversations c ON c.id = cm1.conversation_id
    WHERE c.type = 'direct'
      AND cm1.user_id = current_uid
      AND cm2.user_id = target_user_id
    LIMIT 1;

    IF found_conv_id IS NOT NULL THEN
        RETURN found_conv_id;
    END IF;

    -- Create new conversation
    INSERT INTO public.conversations (type) VALUES ('direct') RETURNING id INTO new_conv_id;

    -- Add both participants
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES 
        (new_conv_id, current_uid),
        (new_conv_id, target_user_id);

    RETURN new_conv_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 5. REALTIME PUBLICATION
-- ==============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- ==============================================================================
-- 6. STORAGE BUCKETS (Avatars, Attachments, Voice Messages)
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('attachments', 'attachments', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('voice_messages', 'voice_messages', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public avatar access'
    ) THEN
        CREATE POLICY "Public avatar access" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users can upload avatars'
    ) THEN
        CREATE POLICY "Authenticated users can upload avatars" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public attachments access'
    ) THEN
        CREATE POLICY "Public attachments access" ON storage.objects FOR SELECT USING (bucket_id = 'attachments');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users can upload attachments'
    ) THEN
        CREATE POLICY "Authenticated users can upload attachments" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'attachments');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public voice messages access'
    ) THEN
        CREATE POLICY "Public voice messages access" ON storage.objects FOR SELECT USING (bucket_id = 'voice_messages');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users can upload voice messages'
    ) THEN
        CREATE POLICY "Authenticated users can upload voice messages" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'voice_messages');
    END IF;
END $$;

-- Explicit PostgREST Foreign Key for conversation_members -> profiles
ALTER TABLE public.conversation_members
DROP CONSTRAINT IF EXISTS fk_conversation_members_profiles;

ALTER TABLE public.conversation_members
ADD CONSTRAINT fk_conversation_members_profiles
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- SAVED THEMES TABLE (Customization Studio)
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

-- STORAGE BUCKET: chat_wallpapers
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

