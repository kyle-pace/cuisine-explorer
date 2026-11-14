"""Tests for the weekly data job. Run with: python3 -m unittest discover -s tests

samples/list-of-cuisines.wikitext is the real Wikipedia page, saved 2026-11-14. Nothing
here goes online or writes into data/.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE = os.path.join(ROOT, "tests", "samples", "list-of-cuisines.wikitext")


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, doc):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f)


def read_text(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def run(script, *args):
    return subprocess.run([sys.executable, os.path.join(ROOT, "scripts", script), *args],
                          capture_output=True, text=True, cwd=ROOT)


class ParseList(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.out = os.path.join(self.tmp, "list_entries.json")

    def test_real_page_gives_the_whole_list(self):
        result = run("parse_list.py", SAMPLE, self.out)
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = read_json(self.out)
        self.assertGreater(len(entries), 600)

        by_key = {e["key"]: e for e in entries}
        japanese = by_key["Japanese cuisine"]
        self.assertEqual(japanese["kind"], "regional")
        self.assertIn("Asian cuisine", " ".join(japanese["sections"][0]))
        # A regional cuisine hangs off its country.
        self.assertIn("Japanese cuisine", by_key["Japanese regional cuisine"]["parents"])
        # The page's themed sections come through as their own kinds.
        self.assertEqual({e["kind"] for e in entries}, {"regional", "style", "religious", "historical"})
        for e in entries:
            self.assertTrue(e["label"], e)
            self.assertTrue(e["group"] or e["title"], e)

    def test_error_page_writes_nothing(self):
        page = os.path.join(self.tmp, "error.wikitext")
        with open(page, "w") as f:
            f.write("<html><body><h1>Wikimedia Error</h1><p>Too many requests</p></body></html>")
        result = run("parse_list.py", page, self.out)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nothing was written", result.stderr)
        self.assertFalse(os.path.exists(self.out))

    def test_half_a_download_writes_nothing(self):
        text = read_text(SAMPLE)
        half = os.path.join(self.tmp, "half.wikitext")
        with open(half, "w", encoding="utf-8") as f:
            f.write(text[: len(text) // 4])
        result = run("parse_list.py", half, self.out)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(os.path.exists(self.out))

    def test_junk_lines_are_skipped(self):
        text = read_text(SAMPLE)
        messy = os.path.join(self.tmp, "messy.wikitext")
        with open(messy, "w", encoding="utf-8") as f:
            # An image, a category, an empty bullet and a broken link, dropped into the middle.
            f.write(text.replace("\n==", "\n* [[File:Dish.jpg|thumb]]\n* [[Category:Food]]\n*\n* [[\n==", 1))
        clean_out = os.path.join(self.tmp, "clean.json")
        self.assertEqual(run("parse_list.py", SAMPLE, clean_out).returncode, 0)
        result = run("parse_list.py", messy, self.out)
        self.assertEqual(result.returncode, 0, result.stderr)
        clean = {e["key"] for e in read_json(clean_out)}
        got = {e["key"] for e in read_json(self.out)}
        self.assertEqual({k for k in got - clean if "File:" in k or "Category:" in k}, set())
        self.assertTrue(clean <= got, "every real cuisine is still there")


class CheckData(unittest.TestCase):
    """scripts/check_data.py, the last step of the weekly refresh."""

    FILES = ["list_entries.json", "cuisines.json", "food.json", "summaries.json", "images.json"]

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.old = os.path.join(self.tmp, "old")
        self.new = os.path.join(self.tmp, "new")
        for folder in (self.old, self.new):
            os.mkdir(folder)
            for name in self.FILES:
                shutil.copy(os.path.join(ROOT, "data", name), folder)

    def test_same_data_passes(self):
        self.assertEqual(run("check_data.py", self.new, self.old).returncode, 0)

    def test_a_few_gone_is_fine(self):
        path = os.path.join(self.new, "food.json")
        food = read_json(path)
        food["dishes"] = food["dishes"][:-20]
        write_json(path, food)
        self.assertEqual(run("check_data.py", self.new, self.old).returncode, 0)

    def test_half_the_dishes_gone_fails(self):
        path = os.path.join(self.new, "food.json")
        food = read_json(path)
        food["dishes"] = food["dishes"][: len(food["dishes"]) // 2]
        write_json(path, food)
        result = run("check_data.py", self.new, self.old)
        self.assertEqual(result.returncode, 1)
        self.assertIn("dishes fell from", result.stderr)

    def test_an_emptied_file_fails(self):
        with open(os.path.join(self.new, "cuisines.json"), "w") as f:
            json.dump({"meta": {}, "cuisines": []}, f)
        self.assertEqual(run("check_data.py", self.new, self.old).returncode, 1)

    def test_a_cut_off_file_fails(self):
        path = os.path.join(self.new, "summaries.json")
        text = read_text(path)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text[: len(text) // 2])
        result = run("check_data.py", self.new, self.old)
        self.assertEqual(result.returncode, 1)
        self.assertIn("can't be read", result.stderr)


if __name__ == "__main__":
    unittest.main()
