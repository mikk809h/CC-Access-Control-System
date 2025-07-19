import os
import json
import fnmatch

# Customize excluded patterns here
EXCLUDE = [
    '.*',                   # hidden files/folders (e.g. .git, .env)
    'node_modules/**',      # node_modules
    '__pycache__/**',       # Python caches
    '*.tmp',                # temp files
]

def is_excluded(path):
    path = path.replace('\\', '/')
    for pattern in EXCLUDE:
        if fnmatch.fnmatch(path, pattern) or fnmatch.fnmatch(os.path.basename(path), pattern):
            return True
    return False

def generate_package_json():
    included_files = []

    for root, dirs, files in os.walk('.'):
        for fname in files:
            rel_path = os.path.join(root, fname).replace('\\', '/')
            if rel_path.startswith('./'):
                rel_path = rel_path[2:]
            if is_excluded(rel_path):
                continue
            included_files.append(rel_path)

    with open('package.meta.json', 'r') as f:
        meta = json.load(f)

    package = {
        "name": meta.get("name", "unnamed-package"),
        "version": meta.get("version", "0.0.1"),
        "description": meta.get("description", ""),
        "author": meta.get("author", ""),
        "repository": meta.get("repository", ""),
        "files": sorted(included_files)
    }

    with open('package.json', 'w') as f:
        json.dump(package, f, indent=2)

    # now update updater.lua if it exists
    if os.path.exists('updater.lua'):
        with open('updater.lua', 'r') as f:
            updater_content = f.readlines()

        for i, line in enumerate(updater_content):
            if "local AUTHOR = " in line:
                updater_content[i] = f"local AUTHOR = \"{meta.get('author', '')}\"\n"
            if "local REPO = " in line:
                updater_content[i] = f"local REPO = \"{meta.get('name', '')}\"\n"
        with open('updater.lua', 'w') as f:
            f.writelines(updater_content)
    else:
        print("Warning: updater.lua not found, skipping update.")
    print(f"✅ package.json updated with {len(included_files)} files.")

if __name__ == '__main__':
    generate_package_json()
