#!/usr/bin/env bash
# Creates the Lightning config file on first run and prints its path.
# An existing file is never touched.
set -euo pipefail

# URLs may carry tokens (webhooks, private dashboards): keep the config
# readable by the owner only.
umask 077

dir="${XDG_CONFIG_HOME:-$HOME/.config}/lightning"
file="$dir/lightning.conf"

mkdir -p "$dir"
if [[ ! -e $file ]]; then
  cat >"$file" <<'CONF'
# Lightning launcher configuration
#
# One entry per line: trigger = URL. Lines starting with # are comments.
# Type the trigger in the launcher and press Enter to open the URL in the
# default browser. Edits are picked up as soon as the file is saved.
#
# A URL may contain a placeholder, {} or %s. Type the trigger, a space and
# some text, and the text (URL-encoded) replaces the placeholder:
# "ddg omarchy plugins" opens https://duckduckgo.com/?q=omarchy%20plugins.
#
# gh   = https://github.com
# ddg  = https://duckduckgo.com/?q=%s
CONF
fi

printf '%s\n' "$file"
