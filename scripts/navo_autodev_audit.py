#!/usr/bin/env python3
"""NAVO SMART hourly read-only audit. Never merges, pushes, or changes safety parameters."""
import json, os, sys, urllib.request
from datetime import datetime, timezone
OWNER_REPO = os.environ.get("NAVO_REPO", "apreuteseicostel/Navosmart")
API = "https://api.github.com/repos/" + OWNER_REPO
TOKEN = os.environ.get("GITHUB_TOKEN", "")
def get(path):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "NAVO-AutoDev-Audit"}
    if TOKEN: headers["Authorization"] = "Bearer " + TOKEN
    req = urllib.request.Request(API + path, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)
def main():
    pulls = get("/pulls?state=open&per_page=100")
    pr = next((p for p in pulls if p["number"] == 23), None)
    if not pr:
        print("PR #23 absent; inspect current integration branch before changing anything.")
        return 2
    sha = pr["head"]["sha"]
    runs = get("/actions/runs?head_sha=" + sha + "&per_page=5").get("workflow_runs", [])
    checks = [{"name":r["name"],"status":r["status"],"conclusion":r["conclusion"],"url":r["html_url"]} for r in runs]
    report = {"checked_at":datetime.now(timezone.utc).isoformat(),"repository":OWNER_REPO,
      "pr":pr["html_url"],"head":sha,"draft":pr["draft"],"checks":checks,
      "master":"docs/NAVO_SMART/PLAN_MASTER_DEEPER_QUEST.md",
      "next":"Fix failing CI before new work; otherwise audit P0 failsafe and RTL. Never merge automatically.",
      "hardware_validation":"deferred until NAVO hardware is assembled"}
    print(json.dumps(report,indent=2,ensure_ascii=False))
    with open("navo-autodev-report.json","w",encoding="utf-8") as out:
        json.dump(report,out,indent=2,ensure_ascii=False)
    if any(r["conclusion"] == "failure" for r in runs if r["status"] == "completed"):
        return 1
    return 0
if __name__ == "__main__":
    try: sys.exit(main())
    except Exception as exc:
        print("Audit failed:",exc,file=sys.stderr)
        sys.exit(3)
