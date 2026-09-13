#!/usr/bin/env bash
# Upload the three guides to Hex as drafts, then publish them.
#   HEX_TOKEN=hxtw_... ./08_upload_hex_guides.sh
# Re-run any time the .md files change; existing guides are updated in place.
set -euo pipefail
: "${HEX_TOKEN:?set HEX_TOKEN}"
cd "$(dirname "$0")/guides"
API="https://app.hex.tech/api/v1"

body=$(python3 - <<'PY'
import json, glob
files = [{"filePath": f, "contents": open(f).read()} for f in sorted(glob.glob("*.md"))]
print(json.dumps({"forceWrite": True, "files": files}))
PY
)
echo "Uploading drafts..."
curl -sS -f -X PUT "$API/guides/draft" -H "Authorization: Bearer $HEX_TOKEN" \
  -H "Content-Type: application/json" --data "$body" \
  | python3 -c 'import json,sys; r=json.load(sys.stdin); [print(" draft:", f.get("filePath"), f.get("id","")) for f in r["files"]]; [print(" warning:", w) for w in r.get("warnings", [])]'

echo "Publishing..."
curl -sS -f -X POST "$API/guides/publish" -H "Authorization: Bearer $HEX_TOKEN" \
  -H "Content-Type: application/json" --data '{"publishAllDraftGuides": true}' \
  | python3 -c 'import json,sys; r=json.load(sys.stdin); print(" ", r.get("message")); [print(" published:", g.get("filePath")) for g in r.get("publishedGuides", [])]'
