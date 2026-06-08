#!/usr/bin/env bash
# Apply FlamAid branding to Chatwoot (idempotent).
# Branding lives in the DB (InstallationConfig), not in env, so this script is the
# version-controlled source of truth. Run from deploy/ on the server:
#   ./branding/apply-branding.sh
#
# Prereqs (one-time, see branding/README.md):
#   - logo assets copied to /root/flamusServer/certbot/www/brand-assets/
#   - nginx `location /brand-assets/` added (see ../nginx/support.flamaid.com.conf)
set -euo pipefail
cd "$(dirname "$0")/.."   # -> deploy/

docker compose exec -T rails bundle exec rails runner '
{
  "INSTALLATION_NAME" => "FlamAid",
  "BRAND_NAME"        => "FlamAid",
  "BRAND_URL"         => "https://flamaid.com",
  "WIDGET_BRAND_URL"  => "https://flamaid.com",
  "PRIVACY_URL"       => "https://www.flamaid.com/policies/privacy-policy",
  "TERMS_URL"         => "https://www.flamaid.com/policies/terms-of-service",
  "LOGO"           => "https://support.flamaid.com/brand-assets/logo.png",
  "LOGO_DARK"      => "https://support.flamaid.com/brand-assets/logo-white.png",
  "LOGO_THUMBNAIL" => "https://support.flamaid.com/brand-assets/icon.png"
}.each { |k, v| InstallationConfig.find_by(name: k)&.update!(value: v) }
GlobalConfig.clear_cache rescue nil
puts "FlamAid branding applied"
'
