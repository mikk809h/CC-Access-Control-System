# Commands to run:
# Robocopy.exe "C:\Users\Mikkel\AppData\Roaming\CraftOS-PC\computer\1" "C:\Users\Mikkel\AppData\Roaming\CraftOS-PC\computer\11" /copyall /MIR /XD "control-server" ".cache" ".git" ".install-cache" ".vscode" /XF ".settings"

# Get the current directory and match
import os
import re
import subprocess
import sys
import json

def get_current_directory():
    # Exclude the .vscode part
    
    current_dir = os.getcwd()
    # Match the pattern to exclude .vscode
    match = re.match(r'^(.*?)(\.vscode)?$', current_dir)
    if match:
        return match.group(1)
    else:
        print("Error: Current directory does not match expected pattern.")
        sys.exit(1)

# TARGET_DIR = r"C:\Users\Mikkel\AppData\Roaming\CraftOS-PC\computer\11"
TARGETS = {
    "control-server": [
        r"C:\Users\Mikkel\AppData\Roaming\CraftOS-PC\computer\12",
        r"C:\Users\Mikkel\curseforge\minecraft\Instances\FTB Skies\saves\Reactor Templating\computercraft\computer\3",
    ],
    "airlock": [
        r"C:\Users\Mikkel\AppData\Roaming\CraftOS-PC\computer\11",
        r"C:\Users\Mikkel\curseforge\minecraft\Instances\FTB Skies\saves\Reactor Templating\computercraft\computer\2",
        r"C:\Users\Mikkel\curseforge\minecraft\Instances\FTB Skies\saves\Reactor Templating\computercraft\computer\4",
    ],
}

excluded_dirs = [
    '.cache',
    '.git',
    '.install-cache',
    '.vscode',
    "logs",
    "data",
]

excluded_files = [
    '.settings'
]


def build_robocopy_args(source, target, mode="control-server"):
    args = [
        "robocopy",
        source,
        target,
        "/COPY:DAT",
        "/MIR",
        "/IS",
        "/IT",
    ]

    if excluded_dirs:
        args.append("/XD")
        args.extend(excluded_dirs)

    if mode == "control-server":
        args.append("airlock")
    elif mode == "airlock":
        args.append("control-server")

    if excluded_files:
        args.append("/XF")
        args.extend(excluded_files)


    return args

def sync_directory(mode="control-server", auto_confirm=False):
    source_dir = get_current_directory()
    targets = TARGETS.get(mode)

    if not targets:
        print(f"❌ No targets configured for mode: {mode}")
        sys.exit(1)

    print(f"Source directory: {source_dir}")
    for target_dir in targets:
        print(f"→ Will sync to: {target_dir}")

    if not auto_confirm:
        confirmation = input("Run this sync? (yes/no): ").strip().lower()
        if confirmation != "yes":
            print("Aborted.")
            return

    for target in targets:
        print(f"\n🔄 Syncing to: {target}")
        args = build_robocopy_args(source_dir, target, mode)
        print("Running command:")
        print(" ".join(args))
        result = subprocess.call(args)
        if result < 8:
            print("✅ Sync completed successfully.")
        else:
            print(f"❌ Robocopy returned exit code {result} — check above for details.")

def sync_all(auto_confirm=False):
    for mode in TARGETS:
        print(f"\n===== Syncing mode: {mode} =====")
        sync_directory(mode=mode, auto_confirm=auto_confirm)

if __name__ == "__main__":
    auto = "--yes" in sys.argv
    sync_all(auto_confirm=auto)