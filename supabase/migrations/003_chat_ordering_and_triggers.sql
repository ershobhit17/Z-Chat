-- Migration: 003_chat_ordering_and_triggers.sql
-- Description: Fixes chat list ordering by adding last_message_at, high-performance index,
-- automated trigger on message insert/update/delete, and realtime publication.

-- 1. Add last_message_at column to conversations if not present
ALTER TABLE public.conversations
ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT now();

-- 2. Backfill last_message_at with the most recent message timestamp in each conversation
UPDATE public.conversations c
SET last_message_at = COALESCE(
  (SELECT MAX(created_at) FROM public.messages m WHERE m.conversation_id = c.id),
  c.created_at
);

-- 3. Create high-efficiency index for ordering conversations by latest activity
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at
ON public.conversations(last_message_at DESC NULLS LAST);

-- 4. Function to automatically maintain conversation last_message_at and updated_at
CREATE OR REPLACE FUNCTION public.handle_message_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    UPDATE public.conversations
    SET last_message_at = NEW.created_at,
        updated_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.conversations
    SET last_message_at = COALESCE(
      (SELECT MAX(created_at) FROM public.messages WHERE conversation_id = OLD.conversation_id AND is_deleted = false),
      created_at
    ),
    updated_at = now()
    WHERE id = OLD.conversation_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- 5. Trigger on messages table
DROP TRIGGER IF EXISTS trg_message_activity ON public.messages;
CREATE TRIGGER trg_message_activity
AFTER INSERT OR UPDATE OF created_at, is_deleted OR DELETE
ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_message_activity();

-- 6. Add RLS policy allowing members to update their conversations
DROP POLICY IF EXISTS "Users can update conversations they belong to" ON public.conversations;
CREATE POLICY "Users can update conversations they belong to"
ON public.conversations
FOR UPDATE
TO authenticated
USING (is_conversation_member(id, auth.uid()))
WITH CHECK (is_conversation_member(id, auth.uid()));

-- 7. Ensure full replica identity for realtime row updates
ALTER TABLE public.conversations REPLICA IDENTITY FULL;

-- 8. Add conversations table to supabase_realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;
END
$$;
