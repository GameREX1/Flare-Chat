-- Flare Chat database schema
-- Run this entire file in Supabase SQL Editor for a fresh project.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  flare_id text not null unique,
  display_name text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  constraint profiles_flare_id_format check (
    flare_id = lower(flare_id)
    and flare_id ~ '^[a-z0-9_]{3,20}$'
  ),
  constraint profiles_display_name_length check (
    char_length(trim(display_name)) between 1 and 40
  )
);

create table if not exists public.contacts (
  user_id uuid not null references public.profiles(id) on delete cascade,
  contact_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, contact_user_id),
  constraint contacts_no_self check (user_id <> contact_user_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  title text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint messages_body_length check (
    char_length(trim(body)) between 1 and 4000
  )
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);
create index if not exists conversation_members_user_idx
  on public.conversation_members (user_id, conversation_id);
create index if not exists contacts_user_idx
  on public.contacts (user_id, created_at desc);

-- Create a profile automatically when a user signs up.
create or replace function public.handle_new_flare_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  chosen_id text;
  chosen_name text;
begin
  chosen_id := lower(trim(coalesce(new.raw_user_meta_data ->> 'flare_id', '')));
  chosen_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));

  insert into public.profiles (id, flare_id, display_name)
  values (new.id, chosen_id, chosen_name);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_flare on auth.users;
create trigger on_auth_user_created_flare
  after insert on auth.users
  for each row execute procedure public.handle_new_flare_user();

-- Helper is SECURITY DEFINER so policies can check membership without recursive RLS.
create or replace function public.is_flare_conversation_member(_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = _conversation_id
      and cm.user_id = auth.uid()
  );
$$;

-- Open an existing one-to-one conversation, or create one safely.
create or replace function public.get_or_create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  found_conversation_id uuid;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  if target_user_id is null or target_user_id = current_user_id then
    raise exception 'Choose another Flare Chat user.';
  end if;

  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'That Flare ID was not found.';
  end if;

  select c.id
    into found_conversation_id
  from public.conversations c
  where c.is_group = false
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = c.id and cm.user_id = current_user_id
    )
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = c.id and cm.user_id = target_user_id
    )
    and (
      select count(*) from public.conversation_members cm
      where cm.conversation_id = c.id
    ) = 2
  limit 1;

  if found_conversation_id is not null then
    return found_conversation_id;
  end if;

  insert into public.conversations (is_group, created_by)
  values (false, current_user_id)
  returning id into found_conversation_id;

  insert into public.conversation_members (conversation_id, user_id)
  values
    (found_conversation_id, current_user_id),
    (found_conversation_id, target_user_id);

  return found_conversation_id;
end;
$$;

-- Keep the conversation's sort timestamp up to date.
create or replace function public.touch_flare_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists on_flare_message_created on public.messages;
create trigger on_flare_message_created
  after insert on public.messages
  for each row execute procedure public.touch_flare_conversation();

-- Enable Row Level Security.
alter table public.profiles enable row level security;
alter table public.contacts enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

-- Profiles contain only public-facing profile details; only signed-in users can discover them.
drop policy if exists "Signed-in users can view profiles" on public.profiles;
create policy "Signed-in users can view profiles"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "Users can view their contacts" on public.contacts;
create policy "Users can view their contacts"
  on public.contacts for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users can add their own contacts" on public.contacts;
create policy "Users can add their own contacts"
  on public.contacts for insert
  to authenticated
  with check (user_id = auth.uid() and contact_user_id <> auth.uid());

drop policy if exists "Users can remove their own contacts" on public.contacts;
create policy "Users can remove their own contacts"
  on public.contacts for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Members can view their conversations" on public.conversations;
create policy "Members can view their conversations"
  on public.conversations for select
  to authenticated
  using (public.is_flare_conversation_member(id));

drop policy if exists "Members can view conversation members" on public.conversation_members;
create policy "Members can view conversation members"
  on public.conversation_members for select
  to authenticated
  using (public.is_flare_conversation_member(conversation_id));

drop policy if exists "Members can view messages" on public.messages;
create policy "Members can view messages"
  on public.messages for select
  to authenticated
  using (public.is_flare_conversation_member(conversation_id));

drop policy if exists "Members can send their own messages" on public.messages;
create policy "Members can send their own messages"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_flare_conversation_member(conversation_id)
  );

-- Enable realtime delivery for messages (safe to re-run).
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

-- Important: never expose a Supabase service_role key in the browser.
-- The frontend uses only the project's public anon/publishable key.
