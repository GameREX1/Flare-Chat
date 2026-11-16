# Flare Chat

Flare Chat is a phone-number-free messaging app. Users sign up with email/password and choose a unique username that acts as their Flare ID.

## Design and current implementation

- Dark black + cyan visual theme
- Responsive signup and login layout
- Custom SVG character carrying a Flare messenger bag, with subtle idle movement and a bag-swing response when the form is focused
- Email/password authentication through Supabase Auth
- Signup metadata stores the chosen Flare ID as `username`
- Profile loading targets the existing `profiles.user_id` and `profiles.username` columns

The bag graphic is an original SVG recreation inspired by the reference. The Coding Stella article loads the visible Visme form through an external embed; it does not publish the form's internal animation source. Flare Chat therefore uses its own form and keeps authentication connected to Supabase.

## Important: this Supabase project already has a database

The connected Supabase project already contains these tables:

- `profiles`
- `conversations`
- `conversation_members`
- `messages`
- `friend_requests`
- `blocked_users`
- `stories`

**Do not run an empty-database bootstrap on this project.** The previous starter schema expected columns such as `profiles.id`, while this project's profile table uses `profiles.user_id` and `profiles.username`.

The file `supabase/schema.sql` is now a read-only inspection query. It does not create, update, or delete tables or data. Use it to inspect the existing columns and keys before applying any schema changes.

## Supabase browser credentials

The current `index.html` contains the Project URL and the public publishable key supplied for this Flare Chat project. It uses the Supabase JavaScript client loaded from a CDN.

The publishable key is intended for browser use when Row Level Security is correctly configured. **Never place a service_role/secret key in browser code.**

## Email authentication

In Supabase, open **Authentication → Providers → Email** and make sure Email is enabled.

For testing, email confirmation may be enabled or disabled according to your project settings. When confirmation is enabled, users confirm their email and then sign in. The app creates or loads the profile using the account's saved signup metadata.

## Hosting

To enable GitHub Pages:

1. Open repository **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select `main` and `/(root)`, then save.
4. Add the GitHub Pages URL to Supabase **Authentication → URL Configuration**.

## Flare ID rules

- 3–20 characters.
- Lowercase letters, numbers and underscores only.
- Unique within Flare Chat.
- No phone number is requested or stored.

## Remaining work

The existing table constraints and Row Level Security policies must be reviewed before enabling friend requests, direct conversations, message sending, stories, and blocking. End-to-end encryption is not currently implemented; do not describe messages as end-to-end encrypted.
