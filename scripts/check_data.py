"""Stop a weekly refresh from replacing good data with a broken or half-empty build.

Compares the freshly built files in data/ with the last committed copies and exits with
an error if any of them is unreadable or has lost more than a sixth of its entries.
Wikipedia and Wikidata do change, so small drops are fine; a big one means a fetch
failed partway. A failed check leaves the run red and nothing is committed.

Usage:
  python3 scripts/check_data.py                 new: data/, old: the last commit
  python3 scripts/check_data.py NEW_DIR OLD_DIR compare two folders (used by the tests)
"""
import json
import os
import subprocess
import sys

# file, path to the collection inside it, what to call it
COUNTS = [
    ("list_entries.json", [], "entries on Wikipedia's list"),
    ("cuisines.json", ["cuisines"], "cuisines"),
    ("food.json", ["dishes"], "dishes"),
    ("food.json", ["ingredients"], "ingredients"),
    ("summaries.json", [], "cuisine intros"),
    ("images.json", ["items"], "photos"),
]
MAX_DROP = 1 / 6


def count(doc, path):
    for key in path:
        doc = doc[key]
    return len(doc)


def load_new(folder, name):
    with open(os.path.join(folder, name), encoding="utf-8") as f:
        return json.load(f)


def load_old(folder, name):
    if folder is not None:
        return load_new(folder, name)
    shown = subprocess.run(["git", "show", f"HEAD:data/{name}"], capture_output=True, text=True)
    if shown.returncode != 0:
        raise FileNotFoundError(name)
    return json.loads(shown.stdout)


def main(new_dir="data", old_dir=None):
    problems = []
    for name, path, label in COUNTS:
        try:
            new = count(load_new(new_dir, name), path)
        except (OSError, ValueError, KeyError, TypeError) as error:
            problems.append(f"{name}: the new file can't be read ({error.__class__.__name__}: {error})")
            continue
        try:
            old = count(load_old(old_dir, name), path)
        except (OSError, ValueError, KeyError, TypeError):
            print(f"ok    {label}: {new} (nothing earlier to compare with)")
            continue
        if new < old * (1 - MAX_DROP):
            problems.append(f"{name}: {label} fell from {old} to {new}")
        else:
            print(f"ok    {label}: {old} -> {new}")
    if problems:
        print("\nThe new data looks broken, so it won't be published:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
