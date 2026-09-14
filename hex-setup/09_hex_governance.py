#!/usr/bin/env python3
"""Hex governance pass via the public API.

  HEX_TOKEN=hxtw_... python3 09_hex_governance.py            # dry run: prints the plan
  HEX_TOKEN=hxtw_... python3 09_hex_governance.py --apply    # makes the changes

What it does
  1. Ensures a group "Customer data access" exists. Members = every ADMIN/MANAGER user
     plus any emails in HEX_GROUP_EMAILS (comma separated). Default adds aris@solsticehealth.co.
  2. For every Prod - <tenant>, CRM (Supabase) and Analytics lake (Athena) connection:
       - sharing: workspace members NONE, guests NONE, public NONE; the group gets QUERY
       - description: one sentence saying what it is and when to use it
  The [Demo] connection is left alone.
"""
import json, os, sys, urllib.request, urllib.error

TOKEN = os.environ.get("HEX_TOKEN") or sys.exit("set HEX_TOKEN")
APPLY = "--apply" in sys.argv
API = "https://app.hex.tech/api/v1"
GROUP_NAME = "Customer data access"
EXTRA_EMAILS = [e.strip().lower() for e in os.environ.get("HEX_GROUP_EMAILS", "aris@solsticehealth.co").split(",") if e.strip()]

# Table access is enforced in the database (allowlist in Backend-Server onboard_tenant.sql);
# Hex schema filters are not used so the agent sees exactly what hex_ro can read.

def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:400]}")

def page(path):
    out, after = [], None
    while True:
        r = call("GET", path + (f"?limit=100&after={after}" if after else "?limit=100"))
        out += r.get("values", [])
        after = (r.get("pagination") or {}).get("after")
        if not after: return out

# 1. group
users = page("/users")
admins = [u for u in users if u["role"] in ("ADMIN", "MANAGER")]
extra = [u for u in users if u["email"].lower() in EXTRA_EMAILS]
members = {u["id"]: u["email"] for u in admins + extra}
missing = [e for e in EXTRA_EMAILS if e not in {u["email"].lower() for u in users}]
groups = page("/groups")
group = next((g for g in groups if g["name"] == GROUP_NAME), None)
print(f"Group '{GROUP_NAME}': {'exists' if group else 'will be created'}")
print("  members:", ", ".join(sorted(members.values())))
if missing: print("  NOT in workspace yet (invite them, then re-run):", ", ".join(missing))
if APPLY:
    if not group:
        group = call("POST", "/groups", {"name": GROUP_NAME, "members": {"users": [{"id": i} for i in members]}})
    else:
        call("PATCH", f"/groups/{group['id']}", {"members": {"add": {"users": [{"id": i} for i in members]}}})

# 2. connections
def desc_for(name, conn):
    if name.startswith("Prod - "):
        t = name.split("Prod - ", 1)[1]
        kind = "test/sandbox tenant, not a real customer" if t in ("testing_demo", "phathom_sandbox", "takeda_sandbox") else f"production database for the customer tenant '{t}'"
        return (f"Solstice platform {kind}. Read-only replica. Use for questions about this one customer: "
                f"assets (n_cg_operations), review requests (admin_requests), brands, users, MLR results. "
                f"See the 'Solstice platform data model' and 'Solstice core metrics' guides.")
    if name.startswith("CRM"):
        return ("Solstice internal CRM. Accounts, deals, and request_drafts (review requests synced daily from every "
                "customer tenant). The only connection where all customers appear together. See the 'Solstice CRM' guide.")
    if name.startswith("Analytics lake"):
        return ("PostHog product analytics for the Solstice web app, exported hourly to S3 and queried with Athena. "
                "Use for usage, adoption, and behaviour questions across all customers. See the 'PostHog product analytics' guide.")
    return None

conns = page("/data-connections")
for c in conns:
    name = c["name"]
    d = desc_for(name, c)
    if not d:
        print(f"skip  {name}"); continue
    patch = {
        "description": d,
        "includeMagic": True,
        "sharing": {"workspace": {"members": "NONE", "guests": "NONE", "public": "NONE"},
                    "groups": [{"group": {"id": group["id"] if group else "<new group>"}, "access": "QUERY"}]},
    }
    cur = c.get("sharing", {}).get("workspace", {})
    print(f"patch {name}: public {cur.get('public')}->NONE, members {cur.get('members')}->NONE (group QUERY)"
)
    if APPLY:
        call("PATCH", f"/data-connections/{c['id']}", patch)

print("\nAPPLIED." if APPLY else "\nDry run only. Re-run with --apply to make these changes.")
