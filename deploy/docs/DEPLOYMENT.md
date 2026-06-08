# FlamAid Chatwoot — Deployment & Maintenance

This repo is a **fork of [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot)**.
It lets us (1) deploy easily, (2) track every change in git, (3) pull upstream
updates, and (4) edit the source (UI/backend) when we need to.

- Branch `flamaid` = our working branch, based on the stable tag **v4.14.1**.
- All deploy artifacts live in `deploy/` so they never conflict with upstream files.
- Source edits (e.g. `app/javascript/...` for UI) live in their normal place and
  are compiled via **build mode**.

## Repos & remotes

```
origin    git@github.com:flamaid-co/chatwoot.git   (our fork)
upstream  git@github.com:chatwoot/chatwoot.git      (the real Chatwoot)
```

## Two deploy modes

| Mode | When | Command (run in `deploy/`) |
|------|------|----------------------------|
| **Image** | No source edits — fast | `./scripts/deploy.sh` |
| **Build** | You edited UI/source | `./scripts/deploy.sh --build` |

Image mode runs the official pinned image (`chatwoot/chatwoot:v4.14.1`).
Build mode compiles a custom image from this repo's `docker/Dockerfile` so your
edits are baked in (first build ~10-20 min).

## First deploy from this repo (server)

```bash
# on the flamaid host
cd /root
git clone https://github.com/flamaid-co/chatwoot.git chatwoot-repo
cd chatwoot-repo && git checkout flamaid
cd deploy
cp .env.example .env
# generate + fill secrets (see .env.example header), then:
./scripts/deploy.sh
# create the first admin (only once):
docker compose run --rm rails bundle exec rails runner '
  acc = Account.create!(name: "FlamAid")
  u = User.new(name: "FlamAid Admin", email: "apps@flamaid.com", password: ENV["ADMIN_PASS"])
  u.skip_confirmation!; u.save!
  AccountUser.create!(account_id: acc.id, user_id: u.id, role: :administrator)'
```

> NOTE: the live instance today runs from `/root/chatwoot` (bootstrapped by hand
> on 2026-06-08). To switch to this repo as source-of-truth, copy that `.env`
> here and re-run; the Docker volumes (data) are independent of the compose path,
> so plan a short maintenance window if migrating.

## Resource isolation (CRITICAL — shared host with Supabase prod)

The flamaid host also runs the **production Supabase backend** that the FlamAid
emergency devices depend on. Chatwoot must never be able to affect it. Guardrails
baked into `docker-compose.yaml`:

- **Hard RAM caps**: rails/sidekiq 1.5G, postgres 1G, redis 512M → ~4.5G ceiling.
  Even fully maxed, Supabase keeps ~25G of the 30G host.
- **`memswap_limit == mem_limit`**: Chatwoot gets no swap; a runaway service
  OOM-kills *itself* (and `restart: always` brings it back) instead of pressuring
  the host.
- **CPU + PIDs caps** and **`oom_score_adj: 500`**: under any host-wide memory
  pressure the kernel kills Chatwoot containers FIRST (Supabase defaults to 0).
- **Log rotation** (10M × 3 per container) so logs can't fill the disk.

Host-level (applied once, outside this repo): an **8G swapfile** + `vm.swappiness=10`
as a cushion that also protects Supabase (the host previously had 0 swap).

Quick health/limits check:
```bash
docker stats --no-stream | grep chatwoot          # live usage vs limits
free -h                                            # host RAM + swap
curl -s http://localhost:3000/api                  # {queue_services, data_services} both "ok"
```
> After recreating the postgres container, the `/api` health may briefly report
> `data_services: failing` until the first real query verifies the pool — it self-
> heals on first use (login, etc.). Not an error.

## Updating Chatwoot (pull upstream)

```bash
git fetch upstream --tags
git checkout flamaid
git merge v4.15.0        # or whatever the new stable tag is
# resolve conflicts (only if you edited source files), commit, push
git push origin flamaid
# then on the server:
cd deploy && ./scripts/deploy.sh           # or --build if you customized source
```

Because our files are under `deploy/`, merges only conflict where *you* changed
upstream source. Pure config/branding-in-`deploy/` updates never conflict.

## Editing the UI

Chatwoot's frontend is Vue, under `app/javascript/`. Edit there, commit on
`flamaid`, push, and deploy with **build mode**. Keep edits minimal to keep
upstream merges painless (see the project memory: "brand, don't fork the engine").

## White-label / build-mode rebrand — DONE (2026-06-08)

Full FLAMAID white-label baked into a custom image. Source edits on `flamaid`:
- **Color → Flame Red `#f32735`**: `theme/colors.js` (`n.brand` + `woot` scale via
  radix `red`/`redDark`); all brand-blue hexes (`#1f93ff`/`#2781F6`) swapped across
  scss/js/vue/erb; `public/manifest.json` + `vueapp.html.erb` theme-color.
- **No "Chatwoot" text**: 70 mentions replaced across `app/javascript/**/i18n/locale/{en,es}`
  + `config/locales/{en,es}.yml` → FLAMAID. (Name/title also via InstallationConfig.)
- **Favicons/app icons**: all 30 `public/*icon*.png` regenerated with the FlamAid flame.

**How it was built & deployed (preserves data volumes):**
```bash
# on the flamaid host
git clone --depth 1 --branch flamaid https://github.com/flamaid-co/chatwoot.git /root/chatwoot-src
cd /root/chatwoot-src && docker build -t flamaid/chatwoot:branded -f docker/Dockerfile .   # ~10-15 min
# point the running stack at the built image (same compose project => same volumes => data kept)
sed -i 's|image: chatwoot/chatwoot:v4.14.1|image: flamaid/chatwoot:branded|' /root/chatwoot/docker-compose.yaml
cd /root/chatwoot && docker compose up -d
```
Build ran safely alongside Supabase (RAM never < 13G free, Supabase healthy throughout).
To rebrand again: edit source on `flamaid`, push, re-clone/pull on server, rebuild, `up -d`.
Verified E2E (Playwright): title "Centre de Support FLAMAID", Login button + `bg-n-brand`
= `rgb(243,39,53)`, zero Chatwoot-blue, zero "Chatwoot" text.

Still blue/legacy: the `n.blue` semantic scale (info states, not brand) is intentionally
left as-is. Remaining cosmetic: `/favicon.ico` 404 (only PNG favicons replaced).

## Phase B — public HTTPS — DONE (2026-06-08)

Live at **https://support.flamaid.com** (Let's Encrypt, proxied through the shared
nginx-proxy to `chatwoot-rails:3000`). Steps actually taken, with the gotchas:

1. **DNS** (Cloudflare): `support.flamaid.com A 91.98.91.232`, **proxy OFF / DNS-only**
   (matches api/studio; needed for direct ACME + origin SSL termination).
2. **Network**: rails joined `supabase_default` with alias `chatwoot-rails`
   (see `docker-compose.yaml` networks). `docker compose up -d rails` to apply.
3. **Cert** (ephemeral certbot, ECDSA, webroot — same as api):
   ```bash
   docker run --rm \
     -v /root/flamusServer/certbot/conf:/etc/letsencrypt \
     -v /root/flamusServer/certbot/www:/var/www/certbot \
     certbot/certbot certonly --webroot -w /var/www/certbot \
     -d support.flamaid.com --key-type ecdsa \
     --email apps@flamaid.com --agree-tos --no-eff-email -n
   ```
4. **nginx**: appended `deploy/nginx/support.flamaid.com.conf` to the host template,
   synced into the container in-place, regenerated, validated, reloaded. See that
   file's header for the **two critical gotchas**: HTTPS must `listen 4443` (host
   maps 443→4443, non-root nginx), and `sed -i` breaks the file bind-mount (sync
   via `docker exec ... cat >` instead).
5. **FRONTEND_URL** = `https://support.flamaid.com` in `.env`, rails restarted.

### Cert auto-renewal (set up 2026-06-08)

There was NO renewal automation on this host (api/studio were issued manually).
Added `/root/flamusServer/certbot/renew.sh` (runs `certbot renew` for ALL certs +
`nginx -s reload`) on a **daily cron at 03:30**. `certbot renew` only acts within
30 days of expiry. Dry-run validated for api + studio + support.

### Safety protocol used (shared prod nginx)

Only **appended** new server blocks (never touched api/studio); `nginx -t` before
every reload; graceful `nginx -s reload` (no restart); backed up `nginx.conf`
before each edit. api/studio verified alive (HTTP 401 = normal) after each step.

## Phase C — the Claude brain (future)

Chatwoot fires a **webhook** on new messages → our backend (Claude + FlamAid RAG)
→ reply via Chatwoot **Application API** → routed back to the original channel.
Postgres here already has **pgvector** for the knowledge base. Build outside this
repo (own service) or under `deploy/` — TBD.
