# Flare Chat

Flare Chat is a phone-number-free messaging app foundation. Users register with an email and choose their own unique **Flare ID** (for example, \`rayyan_01\`). Other users can find them by that ID and start private, real-time conversations.

## Current foundation

- Dark black + cyan responsive interface
- Email/password sign up and sign in
- User-selected, unique Flare IDs (3–20 characters: lowercase letters, numbers, underscores)
- Profile creation on signup
- Find users by exact Flare ID
- Add contacts and open one-to-one conversations
- Real-time private text messaging
- Supabase Row Level Security policies for profiles, contacts, conversations, members and messages

Group chats, file/voice messages, message reactions, notifications, blocking/reporting and end-to-end encryption are not included in this first foundation.

## 1. Create a Supabase project

Create a free Supabase project, then open **SQL Editor → New query**.

Copy the complete contents of \`supabase/schema.sql\` into the editor and run it.

The schema creates the tables, signup trigger, direct-chat RPC, access policies and Realtime publication entry required by the app.

## 2. Add the Supabase browser credentials

In Supabase, open **Project Settings → API** (or **Data API**) and copy:

- Project URL
- Public anon key / publishable key

Open \`index.html\` and find the \`SUPABASE_CONFIG\` object near the top of the application script. Replace the two empty strings:

\`\`\`js
const SUPABASE_CONFIG = {
  url: "https://YOUR-PROJECT.supabase.co",
  anonKey: "YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY"
};
\`\`\`

The public anon/publishable key is intended for browser use when Row Level Security is correctly enabled. **Never use the service_role/secret key in this file.**

## 3. Configure email authentication

In Supabase, open **Authentication → Providers → Email** and make sure Email is enabled.

For initial testing, you can turn email confirmation off in the Supabase Auth settings. For a public launch, keep email confirmation enabled and configure the allowed redirect/site URLs under **Authentication → URL Configuration**.

## 4. Run the app

You can open \`index.html\` with a local static server, or enable GitHub Pages:

1. Open the repository's **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select the \`main\` branch and \`/(root)\`, then save.
4. Add the resulting GitHub Pages URL to Supabase's allowed redirect URLs.

After configuring Supabase, create two test accounts with different Flare IDs in separate browser sessions to test private messaging.

## Flare ID rules

- Must be unique.
- 3–20 characters.
- Lowercase letters, numbers and underscores only.
- No phone number is requested or stored by this app.

## Security notes

The database uses Row Level Security. A signed-in user can read profile fields for ID discovery, but can read messages only in conversations they belong to. Message inserts must use the signed-in user's own profile ID. Keep the database policies enabled.

This is an initial MVP foundation, not a finished production messenger. Before a public launch, add rate limiting/anti-spam controls, abuse reporting and blocking, account recovery, monitoring, and a carefully reviewed privacy/security model. End-to-end encryption is not currently implemented; do not describe messages as end-to-end encrypted.
