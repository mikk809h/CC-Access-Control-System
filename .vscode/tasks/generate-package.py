import os
import json

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

def update_manifest(files, sizes):
    if not os.path.exists(MANIFEST_FILE):
        print(f"Missing: {MANIFEST_FILE}")
        return

    with open(MANIFEST_FILE, "r") as f:
        data = json.load(f)

    data["files"] = files
    data["sizes"] = sizes

    with open(MANIFEST_FILE, "w") as f:
        json.dump(data, f, indent=4)

    print(f"Updated {MANIFEST_FILE} with {sum(len(f) for f in files.values())} files across {len(files)} components")

if __name__ == "__main__":
    patterns = load_gitignore()
    files, sizes = collect_files(patterns)
    update_manifest(files, sizes)
