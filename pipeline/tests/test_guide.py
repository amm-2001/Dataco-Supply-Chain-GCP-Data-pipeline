"""Checks that the guide explains every file of the pipeline."""
import re
import subprocess
import sys


def guide_text(project_root):
    """The guide, exported from the doc as Markdown."""
    return (project_root.parent / "docs" / "guide" / "dataco-gcp-guide.md").read_text()


def test_guide_covers_every_pipeline_file(project_root):
    guide = guide_text(project_root)
    for path in project_root.rglob("*"):
        if path.is_file() and path.suffix in {".sh", ".py", ".sql", ".yaml"} and "__pycache__" not in str(path):
            if path.name in {"conftest.py", "contract.py"} or path.name.startswith("test_"):
                continue  # test helpers are introduced together in chapter 9
            assert path.name in guide, f"guide never mentions {path.name}"


def test_guide_has_five_part_format_per_script(project_root):
    guide = guide_text(project_root)
    assert guide.count("Check it worked") >= 25
    assert guide.count("Line by line") >= 20


def test_guide_code_matches_the_real_files(project_root):
    # Every code excerpt in the guide that comes from a project file must match
    # that file line for line, so the guide never teaches outdated code.
    import re

    guide = guide_text(project_root)
    files = [p.read_text() for p in project_root.rglob("*")
             if p.is_file() and p.suffix in {".sh", ".py", ".sql", ".yaml", ".txt"}]
    for block in re.findall(r"```\w+\n(.*?)```", guide, re.S):
        lines = [line for line in block.splitlines() if line.strip() and "..." not in line]
        if len(lines) < 8:
            continue
        best = max(files, key=lambda text: sum(line in text for line in lines))
        matched = sum(line in best for line in lines)
        if matched / len(lines) >= 0.5:          # this block is an excerpt of `best`
            assert matched == len(lines), [line for line in lines if line not in best][:3]


def test_guide_states_the_real_number_of_tests(project_root):
    # Chapter 9 tells the reader how many tests to expect; keep it honest.
    # Ask pytest itself how many tests it finds: a parametrized test counts
    # once per case, exactly like in the "N passed" line.
    collected = subprocess.run(
        [sys.executable, "-m", "pytest", "--collect-only", "-q", "tests"],
        cwd=project_root, capture_output=True, text=True,
    ).stdout
    count = int(re.search(r"(\d+) tests? collected", collected).group(1))
    guide = guide_text(project_root)
    assert f"{count} passed" in guide
    assert f"runs {count} automatic tests" in guide
