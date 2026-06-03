#!/usr/bin/env python3
# need TIER_CONFIGS_DIR and MOBILE_DOCUMENTATION_DIR env vars (or pass as args)
# usage: config-update <CONFIG_VERSION> <ENV> [<TIER_CONFIGS_DIR> <MOBILE_DOCUMENTATION_DIR>]

import argparse
import os
import re
import sys
import subprocess
from pathlib import Path

tier_configs_dir = ""
mobile_documentation_dir = ""

repo_tiers = {
    "api-mobile-backend-isl": ["ccm", "islb", "islc"],
    "api-mobile-menu-ordering": ["ccm", "islb", "islc"],
    "api-mobile-ordering-services": ["islb", "islc", "payservice"],
    "api-mobile-promotion-discount-service": ["islb", "islc"],
    "api-mobile-notification-service": ["islb", "islc"],
    "api-mobile-backend-fcm": ["islb"],
    "api-mobile-backend-lcm": ["islb"],
    "api-mobile-backend-rcm": ["islb"],
    "api-mobile-batch-services": ["batch", "mw"],
    "api-mobile-server-lambda": ["batch"],
    "api-mobile-gateway": ["mbg"],
    "api-mobile-vendor-gateway": ["mbg"],
    "api-mobile-payment-gateway": ["pg"],
    "webui-mobile-ccm": ["ccm"],
    "webui-mobile-menu-authoring": ["ma"],
}

repo_property_files = {
    "api-mobile-backend-isl":                   "wawaisl.properties",
    "api-mobile-backend-lcm":                   "wawaisl-lcm.properties",
    "api-mobile-backend-rcm":                   "wawaisl-rcm.properties",
    "api-mobile-backend-fcm":                   "wawaisl-fcm.properties",
    "api-mobile-menu-ordering":                  "wawa-menu-ordering.properties",
    "api-mobile-ordering-services":              "paymentservice.properties",
    "api-mobile-notification-service":           "notification-service.properties",
    "api-mobile-promotion-discount-service":     "promotion-service.properties",
    "api-mobile-batch-services":                 "wawaisl-batchservice.properties",
    "api-mobile-server-lambda":                  "application-wawaprd.properties",
    "api-mobile-gateway":                        "wawamg.properties",
    "api-mobile-payment-gateway":                "wawapg.properties",
    "webui-mobile-ccm":                          "wawaisl-ccm.properties",
    "webui-mobile-menu-authoring":               "wawa-menu-authoring.properties",
}

def git_checkout_pull(directory: str, branch: str):
    result = subprocess.run(["git", "-C", directory, "checkout", branch], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"git checkout '{branch}' failed in {directory}:\n{result.stderr.strip()}")
        sys.exit(result.returncode)

    result = subprocess.run(["git", "-C", directory, "pull"], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"git pull failed in {directory}:\n{result.stderr.strip()}")
        sys.exit(result.returncode)

def build_path(env: str, tier: str, module: str):
    return f"{tier_configs_dir}/ENVS/{env}/{tier}/etc/wawa/{repo_property_files[module]}"

def parse_properties(properties_body: str):
    properties = []
    lines = [l.strip() for l in properties_body.strip().splitlines() if l.strip()]
    # first line is header, second is separator, rest are data rows
    if len(lines) < 3:
        return properties
    headers = [h.strip() for h in lines[0].strip('|').split('|')]
    for line in lines[2:]:
        values = [v.strip() for v in line.strip('|').split('|')]
        properties.append(dict(zip(headers, values)))
    return properties

def actionalize_property(property_name: str, value: str, action: str, file_path: str):
    path = Path(file_path)
    if not path.exists():
        print(f"  [warn] File not found: {file_path}")
        return

    lines = path.read_text().splitlines(keepends=True)
    action = action.strip().lower()

    if action == "add":
        if dry_run:
            print(f"  [dry-run] Would add '{property_name}={value}' to {file_path}")
            return
        lines.append(f"{property_name}={value}\n")
        path.write_text("".join(lines))
        print(f"  Added '{property_name}={value}' in {file_path}")

    elif action in ("update", "modify"):
        new_lines = []
        found = False
        for line in lines:
            if re.match(rf'^\s*{re.escape(property_name)}\s*=', line):
                if dry_run:
                    print(f"  [dry-run] Would update '{property_name}' to '{value}' in {file_path}")
                    return
                new_lines.append(f"{property_name}={value}\n")
                found = True
            else:
                new_lines.append(line)
        if not found:
            print(f"  [warn] Property '{property_name}' not found for update in {file_path}")
            return
        path.write_text("".join(new_lines))
        print(f"  Updated '{property_name}={value}' in {file_path}")

    elif action in ("remove", "delete"):
        new_lines = [l for l in lines if not re.match(rf'^\s*{re.escape(property_name)}\s*=', l)]
        if len(new_lines) == len(lines):
            print(f"  [warn] Property '{property_name}' not found for removal in {file_path}")
            return
        if dry_run:
            print(f"  [dry-run] Would remove '{property_name}' from {file_path}")
            return
        path.write_text("".join(new_lines))
        print(f"  Removed '{property_name}' from {file_path}")

    else:
        print(f"  [warn] Unknown action '{action}' for property '{property_name}'")

def process_property(property: dict):
    if property["Externalize"] == "Yes":
        property_file_paths = []
        module = property["Module"]
        property_name = property["Property Name"]
        value = property["Property Value"]
        action = property["Action"]
        for tier in repo_tiers[module]:
            property_file_paths.append(build_path(env, tier, module))
        for file_path in property_file_paths:
            actionalize_property(property_name, value, action, file_path)
    return 0

def main():
    parser = argparse.ArgumentParser(
        description="Update tier configs and mobile documentation for a release.",
        usage="config-update <CONFIG_VERSION> <ENV> [<TIER_CONFIGS_DIR> <MOBILE_DOCUMENTATION_DIR>] [--dry-run]"
    )
    parser.add_argument("config_version")
    parser.add_argument("env")
    parser.add_argument("tier_configs_dir_arg", nargs="?", default="")
    parser.add_argument("mobile_documentation_dir_arg", nargs="?", default="")
    parser.add_argument("--dry-run", action="store_true", help="Print actions without applying changes or creating branches")
    parsed = parser.parse_args()

    global tier_configs_dir, mobile_documentation_dir, dry_run, env
    config_version = parsed.config_version
    env = parsed.env
    dry_run = parsed.dry_run
    tier_configs_dir = parsed.tier_configs_dir_arg or os.environ.get("TIER_CONFIGS_DIR", "")
    mobile_documentation_dir = parsed.mobile_documentation_dir_arg or os.environ.get("MOBILE_DOCUMENTATION_DIR", "")

    if dry_run:
        print("[dry-run] No changes will be applied.")

    if not tier_configs_dir:
        print("Set 'TIER_CONFIGS_DIR' env var to your local tier configurations path (https://github.com/wawa/iac-mobile-tier-configurations)")
        sys.exit(5)

    if not mobile_documentation_dir:
        print("Set 'MOBILE_DOCUMENTATION_DIR' env var to your local mobile documentation path (https://github.com/wawa/tool-mobile-documentation)")
        sys.exit(5)

    # Tier Configs Repo: checkout proper version based on config_version
    # ex: config_version = 26.1.0.2, checkout release/26.1.0.x
    branch = "release/" + re.sub(r'\.[0-9]+$', '.x', config_version)
    git_checkout_pull(tier_configs_dir, branch)

    # Create new working branch
    new_branch = f"{env}-{config_version}"
    if dry_run:
        print(f"[dry-run] Would create branch: {new_branch}")
    else:
        result = subprocess.run(["git", "-C", tier_configs_dir, "checkout", "-b", new_branch], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"git checkout -b '{new_branch}' failed in {tier_configs_dir}:\n{result.stderr.strip()}")
            sys.exit(result.returncode)
        print(f"Created and checked out branch: {new_branch}")

    # Mobile documentation repo: checkout develop
    git_checkout_pull(mobile_documentation_dir, "develop")

    # Find folder named "v<config_version>" in mobile documentation repo
    matches = [p for p in Path(mobile_documentation_dir).rglob(f"v{config_version}") if p.is_dir()]
    if not matches:
        print(f"Could not find directory 'v{config_version}' in {mobile_documentation_dir}")
        sys.exit(1)

    version_dir = matches[0]
    print(f"Found version directory: {version_dir}")

    # Iterate through files under the version directory
    for file in version_dir.rglob("*"):
        if file.is_file():
            print(f"Processing: {file}")
            # TODO: process file content
            content = file.read_text()
            sections = re.split(r'(?=^### )', content, flags=re.MULTILINE)
            for section in sections:
                if not section.strip():
                    continue
                header, _, body = section.partition('\n')
                if(header.strip() == "### Properties Changes:"):
                    property_changes = parse_properties(body.strip())

    for property in property_changes:
        process_property(property)

if __name__ == "__main__":
    main()

