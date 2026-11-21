# Vercel + Supabase setup checklist

## Vercel

1. Push the project to a private Git repository you control.
2. Import the repository into Vercel.
3. Confirm the project is detected as TanStack Start and that Nitro is configured for Vercel (the current `@lovable.dev/vite-tanstack-config` wrapper must be checked because this source comments that its default Nitro target is Cloudflare).
4. Use the project root as the Root Directory unless the repository layout changes.
5. Set the environment variables listed below for Preview and Production.
6. Deploy a Preview first; do not point the public domain to an untested deployment.

## Environment variables

| Variable | Vercel exposure | Purpose |
|---|---|---|
| `VITE_SUPABASE_URL` | Browser-visible | Supabase project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Browser-visible | Supabase publishable key |
| `SUPABASE_URL` | Server-only | Supabase URL for server functions |
| `SUPABASE_PUBLISHABLE_KEY` | Server-only | Supabase key used by server auth middleware |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only secret | Admin Auth API operations; bypasses RLS, protect carefully |

Never set the service-role key under a `VITE_` name.

## Supabase

1. Create/select the production project.
2. Apply the SQL migrations in `supabase/migrations/` in timestamp order after reviewing them in a non-production project.
3. Configure Auth site URL and allowed redirect URLs for the Vercel preview and production domains.
4. Configure email confirmation and appropriate abuse protection/rate limits.
5. Review RLS on every exposed table with Supabase Security Advisor.
6. Create separate public-media and private-payment-proof buckets with separate policies.
7. Take a backup before any production schema/data migration.

## Important

This file is a checklist, not proof that the remote Vercel or Supabase projects are configured. Do not share service-role keys, database passwords, email credentials, or payment-provider secrets in chat or source control.
