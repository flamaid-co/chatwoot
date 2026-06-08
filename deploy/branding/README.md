# FlamAid branding

Config-level rebranding (no source fork → survives upstream updates). Done 2026-06-08.

## What's branded

| Surface | Value |
|---|---|
| App name (`INSTALLATION_NAME`, page title) | FlamAid |
| Brand name + URLs (`BRAND_NAME`, `BRAND_URL`, `WIDGET_BRAND_URL`) | flamaid.com |
| Privacy / Terms links | flamaid.com/policies/* |
| Logos (`LOGO`, `LOGO_DARK`, `LOGO_THUMBNAIL`) | `assets/` served via nginx |
| Default locale (`.env` `DEFAULT_LOCALE`) | es |

Verified end-to-end: login page shows the FlamAid logo + "Login to FlamAid".

## Assets

`assets/` holds the FlamAid logos (pulled from flamaid.com):
- `logo.png` — full logo, light backgrounds (login, expanded sidebar)
- `logo-white.png` — full logo, dark mode
- `icon.png` — square flame mark (collapsed sidebar, thumbnail)

They are **self-hosted** (no external CDN dependency): copied to the host webroot
that nginx already mounts, and served at `https://support.flamaid.com/brand-assets/`.

## How to (re)apply on the server

```bash
# 1. assets -> webroot already mounted into nginx-proxy
mkdir -p /root/flamusServer/certbot/www/brand-assets
cp deploy/branding/assets/*.png /root/flamusServer/certbot/www/brand-assets/

# 2. nginx already serves them via `location /brand-assets/` in the support block
#    (see ../nginx/support.flamaid.com.conf). If missing, add it + sync + reload.

# 3. apply the DB config
cd deploy && ./branding/apply-branding.sh
```

To change a logo: replace the file in `assets/`, copy to the webroot, hard-refresh
(assets have `expires 7d`; bump the filename or purge if needed).

## Not done (needs build mode = source edit)

- **Accent/theme color** across the dashboard (FlamAid "Flame Red"). Chatwoot's
  dashboard accent isn't a config value; it requires editing SCSS and building a
  custom image (`docker-compose.build.yaml`). Tracked as a future build-mode task.
- **Favicon** (`/favicon.ico`) — shipped in `public/`; replace via build mode.
