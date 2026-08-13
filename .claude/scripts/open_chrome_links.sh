#!/usr/bin/env bash
# Open target URLs in Google Chrome (new window in background or new instance)

if [ $# -eq 0 ]; then
  echo "No URLs provided."
  exit 0
fi

urls=("$@")

if pgrep -x "Google Chrome" > /dev/null 2>&1; then
  applescript='tell application "Google Chrome"
set newWindow to make new window
set URL of active tab of newWindow to "'"${urls[0]}"'"'
  for url in "${urls[@]:1}"; do
    applescript+='
tell newWindow to make new tab with properties {URL:"'"$url"'"}'
  done
  applescript+='
end tell'
  osascript -e "$applescript" > /dev/null
  echo "✓ Opened ${#urls[@]} links in a new Chrome window (background)"
else
  open -a "Google Chrome" "${urls[@]}"
  echo "✓ Launched Chrome with ${#urls[@]} tabs"
fi
