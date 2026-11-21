# Off Track — Production Readiness Audit

Date: 2026-11-21
Target: Vercel (TanStack Start/Nitro) + Supabase (Postgres, Auth, Storage)

## Current project structure

The uploaded source is a TanStack Start + React + TypeScript application. It already contains the storefront, account pages, cart/wishlist state, admin pages, Supabase client setup, and SQL migrations for products, categories, orders, profiles, roles, settings, inventory, prices, discounts, banners, and product images.

This is a source-code audit only. No connection was made to the owner's Vercel or Supabase projects, and no deployment or live database changes were performed.

## Launch blockers found in the source

### P0 — Order creation trusts the browser

`src/routes/checkout.tsx` calculates item prices, subtotal, shipping, and total in the browser, then inserts those values directly into `orders`. A modified browser request can submit a different price, quantity, total, item list, status, or payment status. Production checkout must call a trusted server function or a single Postgres RPC that recalculates prices and shipping from database records, validates active products and stock, and creates the order atomically.

The checkout form collects `phone`, but the insert does not save it. The existing `orders` table migration also has no customer phone column. Add a phone column and persist it as part of the trusted order-creation flow.

The current stock model is split: the product form edits `products.stock`, while the storefront may replace it with the sum of `inventory.quantity`. Before checkout decrements stock, decide on one authoritative inventory model (including size/color variants) and migrate existing values consistently.

### P0 — Payment proof shares the public category-images bucket

`src/lib/storage-upload.ts` uploads InstaPay proof files into `category-images`. The migration `20260711000918_...sql` grants public SELECT on every object in that bucket. Therefore payment-proof images uploaded there are publicly readable by anyone who obtains their URL. The same migration permits any authenticated account to upload, update, and delete objects in that bucket; the policies do not require the admin role.

Create a separate private `payment-proofs` bucket. Permit a customer to upload only into a path scoped to their own authenticated user ID, prevent customers from reading other proofs, and let admins review proofs using server-generated short-lived signed URLs. Keep public product/category/hero images in a separate public bucket. Do not reuse long-lived signed URLs for private payment proofs.

### P0 — First-admin claim is exposed to every signed-in account until claimed

The `claim_first_admin()` function grants the admin role to whichever authenticated account calls it first while no admin exists. This is an unsafe bootstrap flow if public registration is enabled before the store owner claims the role. The existence check is also not serialized against concurrent claims.

Before public launch, provision the first owner/admin from a trusted Supabase dashboard or a one-time protected server operation, then remove/revoke the public claim path. If retaining a claim flow for local setup, serialize it with a transaction-level advisory lock and keep it disabled in production after bootstrap.

### P1 — Admin server functions need a server-only secret

`src/lib/admin-users.functions.ts` imports `supabaseAdmin` for creating, listing, updating, and deleting admin users. `src/integrations/supabase/client.server.ts` requires `SUPABASE_SERVICE_ROLE_KEY`, but the supplied `.env` file does not define it. Add the Supabase service-role secret only to Vercel server environment variables (and a local ignored `.env`); never prefix it with `VITE_`, commit it, or expose it to browser code.

### P1 — Storage authorization needs role/path restrictions

The category-images storage policies currently authorize all authenticated users rather than admins. Replace them with admin-only write policies. Public read should apply only to the public-media bucket. Private proof files must use a different bucket and stricter policies.

### P1 — Image upload strategy is inconsistent

Product images are converted to base64 data URLs by `fileToCompressedDataUrl()` and stored in the `products` table, while category and hero images use Storage signed URLs. Move public product/category/hero images to a public Storage bucket and store stable object paths or public URLs in Postgres. This avoids bloating product rows and avoids signed URLs expiring or needing 10-year signatures.

### P1 — Vercel deployment target is not yet verified

`vite.config.ts` delegates configuration to `@lovable.dev/vite-tanstack-config`. Its own comments state that it injects Nitro with Cloudflare as the default target. The project also contains `src/server.ts` and server functions. Vercel's current TanStack Start guidance uses Nitro's Vercel integration. Verify/migrate the Vite plugin configuration to the supported Nitro Vercel target before deploying; do not assume the current Lovable wrapper output is Vercel-compatible merely because `nitro` is present in `package.json`.

### P1 — Build not verified in this environment

`npm ci --ignore-scripts --no-audit --no-fund` did not complete within the available execution window, so `npm run build` and lint could not be run. Re-run dependency installation and the build in the repository's normal development environment or CI before deployment.

## Required environment variables

Client-safe (Vite exposes `VITE_` variables to the browser):

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Server-only (never use the `VITE_` prefix):

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (only for trusted server-side admin operations)

Set the variables in Vercel for Development, Preview, and Production as appropriate. Use the matching Supabase project URL and keys for each environment. Do not put secrets in GitHub or client-side variables.

## Recommended implementation order

1. Secure bootstrap/admin authorization and Storage bucket policies.
2. Implement trusted, atomic order creation: server validates products/prices/discounts/shipping/stock and persists phone + immutable order-line snapshots.
3. Split public media from private payment proofs; replace 10-year signed URLs for private files.
4. Normalize stock and variant inventory; add atomic reservation/decrement and cancellation/restock behavior.
5. Complete payment workflow. Cash on delivery can be marked pending; InstaPay remains unverified until an admin reviews proof. Do not label a customer-uploaded screenshot as a verified payment. Add a payment provider only after choosing a supported provider and obtaining merchant credentials.
6. Configure Vercel/Nitro, add environment variables, connect the repository, and deploy a Preview environment first.
7. Run end-to-end tests for registration, login, admin access, product CRUD, cart, stock validation, COD order, InstaPay proof privacy, order status changes, Arabic/English RTL/LTR, and mobile layouts.
8. Configure domain, transactional email, backups, monitoring, rate limits, and production policies before opening the store publicly.

## Release acceptance criteria

- A customer cannot change product prices, shipping fees, totals, order status, or payment status by editing browser requests.
- A customer can read only their own orders and cannot read another customer's address, phone, or payment proof.
- Only admins can change catalog, stock, settings, and order statuses.
- Payment proofs are private and accessible only to the owner and authorized admins.
- Stock cannot become negative when two customers order the last unit concurrently.
- Checkout stores a verified phone number and a server-calculated order total.
- Build, lint, migration checks, and preview deployment all pass.
