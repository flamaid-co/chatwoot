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

## Phase B — make it public (HTTPS)

1. DNS: `support.flamaid.com  A  91.98.91.232`
2. Attach the rails container to the proxy network so nginx can reach it:
   add to `docker-compose.yaml` (or a Phase-B override) under `rails:` —
   ```yaml
   networks: [default, supabase_default]
   # and at file end:
   # networks:
   #   supabase_default:
   #     external: true
   ```
   with a network alias `chatwoot-rails`.
3. Issue the cert and install the server block:
   ```bash
   docker exec nginx-proxy certbot certonly --webroot -w /var/www/certbot \
     -d support.flamaid.com --email apps@flamaid.com --agree-tos -n
   # add deploy/nginx/support.flamaid.com.conf into /root/flamusServer/nginx/nginx.conf
   docker exec nginx-proxy nginx -s reload    # no recreate = no downtime for api/studio
   ```
4. Set `FRONTEND_URL=https://support.flamaid.com` in `.env` and restart rails.

## Phase C — the Claude brain (future)

Chatwoot fires a **webhook** on new messages → our backend (Claude + FlamAid RAG)
→ reply via Chatwoot **Application API** → routed back to the original channel.
Postgres here already has **pgvector** for the knowledge base. Build outside this
repo (own service) or under `deploy/` — TBD.
