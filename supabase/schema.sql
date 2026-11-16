-- Flare Chat existing database inspection (READ ONLY)
-- IMPORTANT:
-- This project already has existing tables:
-- profiles, conversations, conversation_members, messages,
-- friend_requests, blocked_users, stories.
-- Do NOT run a fresh-database bootstrap against this project.
-- This file only reads metadata; it does not modify or delete data.

SELECT
    'COLUMN' AS item_type,
    c.table_name,
    c.column_name,
    c.data_type,
    CASE WHEN c.is_nullable = 'YES' THEN 'nullable' ELSE 'not null' END AS details
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
    'profiles',
    'conversations',
    'conversation_members',
    'messages',
    'friend_requests',
    'blocked_users',
    'stories'
  )

UNION ALL

SELECT
    tc.constraint_type AS item_type,
    tc.table_name,
    COALESCE(kcu.column_name, '') AS column_name,
    '' AS data_type,
    CASE
      WHEN ccu.table_name IS NOT NULL
        THEN ccu.table_name || '.' || ccu.column_name
      ELSE tc.constraint_name
    END AS details
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.constraint_schema = kcu.constraint_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
 AND tc.constraint_schema = ccu.constraint_schema
WHERE tc.constraint_schema = 'public'
  AND tc.table_name IN (
    'profiles',
    'conversations',
    'conversation_members',
    'messages',
    'friend_requests',
    'blocked_users',
    'stories'
  )
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE')

UNION ALL

SELECT
    'RLS POLICY' AS item_type,
    p.tablename AS table_name,
    p.policyname AS column_name,
    array_to_string(p.roles, ', ') AS data_type,
    'command=' || p.cmd
      || '; using=' || COALESCE(p.qual, '-')
      || '; check=' || COALESCE(p.with_check, '-') AS details
FROM pg_policies p
WHERE p.schemaname = 'public'
  AND p.tablename IN (
    'profiles',
    'conversations',
    'conversation_members',
    'messages',
    'friend_requests',
    'blocked_users',
    'stories'
  )
ORDER BY table_name, item_type, column_name;
