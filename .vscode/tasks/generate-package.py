import os
import json
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Update install_manifest.json based on file changes.")
    parser.add_argument("--bump", type=str, choices=["major", "minor", "revision"], required=True,
                        help="Version bump type: major, minor, or revision")
    return parser.parse_args()


def bump_type_to_mode(bump_type: str) -> int:
    return {"major": 1, "minor": 2, "revision": 3}[bump_type]

MANIFEST_FILE = "install_manifest.json"
GITIGNORE_FILE = ".gitignore"

# Manual exclusions — always ignored
EXCLUDED_PATHS = {
    ".git",
    ".vscode",
    "spec",
    "tests",
    MANIFEST_FILE,
    GITIGNORE_FILE,
    ".generate_package.py",
    "logs",
    ".settings",
    ".install-cache",
}

def load_gitignore():
    patterns = []
    if os.path.exists(GITIGNORE_FILE):
        with open(GITIGNORE_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                patterns.append(line)

    # Now add those to EXCLUDED_PATHS
    for pattern in patterns:
        # Only add if not already excluded
        if not any(pattern.startswith(excluded) for excluded in EXCLUDED_PATHS):
            EXCLUDED_PATHS.add(pattern)

    return patterns

def is_ignored(path, ignore_patterns):
    path = path.replace("\\", "/")
    path_parts = path.split("/")

    if path_parts[0] in EXCLUDED_PATHS:
        return True

    for pattern in ignore_patterns:
        if pattern.endswith("/"):
            if path.startswith(pattern):
                return True
        elif "*" in pattern:
            import fnmatch
            if fnmatch.fnmatch(path, pattern):
                return True
        else:
            if path == pattern:
                return True
    return False

def categorize_file(path):
    parts = path.split("/")
    if len(parts) == 1:
        return "system"
    return parts[0]

def collect_files(ignore_patterns):
    files_by_component = {}
    sizes_by_component = {}

    for root, _, files in os.walk("."):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, ".").replace("\\", "/")

            if is_ignored(rel_path, ignore_patterns):
                continue

            component = categorize_file(rel_path)
            files_by_component.setdefault(component, []).append(rel_path)
            sizes_by_component[component] = sizes_by_component.get(component, 0) + os.path.getsize(full_path)

    # Sort file lists
    for file_list in files_by_component.values():
        file_list.sort()

    return files_by_component, sizes_by_component

def prompt_update_type():
    print("What update type is this?")
    print("  1. Major   → resets Minor and Revision, increments Major")
    print("  2. Minor   → resets Revision, increments Minor")
    print("  3. Revision → increments Revision")
    
    while True:
        choice = input("Select 1 / 2 / 3: ").strip()
        if choice in {"1", "2", "3"}:
            return int(choice)
        print("Invalid input. Please choose 1, 2, or 3.")

def bump_version(version: str, mode: int) -> str:
    major, minor, rev = map(int, version.strip().split("."))
    if mode == 1:
        return f"{major + 1}.0.0"
    elif mode == 2:
        return f"{major}.{minor + 1}.0"
    elif mode == 3:
        return f"{major}.{minor}.{rev + 1}"
    return version

def update_manifest(files, sizes, bump_type):
    if not os.path.exists(MANIFEST_FILE):
        print(f"Missing: {MANIFEST_FILE}")
        return

    with open(MANIFEST_FILE, "r") as f:
        manifest = json.load(f)

    prev_files = manifest.get("files", {})
    prev_sizes = manifest.get("sizes", {})
    prev_versions = manifest.get("versions", {})

    # bump_type = prompt_update_type()
    changed = []

    for component, new_file_list in files.items():
        old_file_list = prev_files.get(component, [])
        old_size = prev_sizes.get(component, 0)
        new_size = sizes[component]

        if new_file_list != old_file_list or new_size != old_size:
            changed.append(component)

    if not changed:
        print("No changes detected. No version bumps made.")
    else:
        for component in changed:
            old_version = prev_versions.get(component, "0.0.0")
            new_version = bump_version(old_version, bump_type)
            prev_versions[component] = new_version
            print(f"→ {component}: {old_version} → {new_version}")

    # Write updated manifest
    manifest["files"] = files
    manifest["sizes"] = sizes
    manifest["versions"] = prev_versions

    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=4)

    print(f"\nUpdated {MANIFEST_FILE} with {sum(len(f) for f in files.values())} files across {len(files)} components")


if __name__ == "__main__":
    args = parse_args()
    bump_mode = bump_type_to_mode(args.bump)

    patterns = load_gitignore()
    files, sizes = collect_files(patterns)
    update_manifest(files, sizes, bump_mode)