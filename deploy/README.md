# FlamAid Chatwoot — `deploy/`

Everything FlamAid-specific for running our Chatwoot lives here, isolated from
upstream files so updates stay merge-friendly.

| File | What |
|------|------|
| `docker-compose.yaml` | Production stack (pinned official image) |
| `docker-compose.build.yaml` | Override to build a custom image from our source (UI edits) |
| `.env.example` | Env template — copy to `.env`, fill secrets (never commit `.env`) |
| `nginx/support.flamaid.com.conf` | Public HTTPS server block (Phase B) |
| `scripts/deploy.sh` | One-command deploy (`--build` for source edits) |
| `docs/DEPLOYMENT.md` | Full runbook: deploy, update from upstream, edit UI, go public |

Quick start: see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

This is a fork of [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot);
our work lives on the `flamaid` branch (based on stable tag `v4.14.1`).
