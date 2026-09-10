"""Render Busted and benchmark results as GitHub Markdown."""

import argparse
import html
import json
import statistics
import xml.etree.ElementTree as ET
from pathlib import Path


def cell(value):
    return html.escape(str(value)).replace("|", "&#124;").replace("\n", "<br>")


def tests(path):
    print("## Tests\n")
    if not path.exists():
        print("❌ No test report was produced. See the setup and test steps for details.")
        return
    root = ET.parse(path).getroot()
    cases = list(root.iter("testcase"))
    failures = list(root.iter("failure"))
    errors = list(root.iter("error"))
    skipped = list(root.iter("skipped"))
    print(f"**{len(cases)} tests · {len(failures)} failures · {len(errors)} errors · {len(skipped)} skipped**\n")
    print("| Result | Test |\n| :--- | :--- |")
    for case in cases:
        status = "✅ Passed"
        if case.find("failure") is not None:
            status = "❌ Failed"
        elif case.find("error") is not None:
            status = "❌ Error"
        elif case.find("skipped") is not None:
            status = "⏭️ Skipped"
        print(f"| {status} | {cell(case.get('name', 'Unnamed test'))} |")
    for issue in failures + errors:
        print("\n<details><summary>Failure / error details</summary>\n")
        print("<pre>" + html.escape("".join(issue.itertext())) + "</pre>\n\n</details>")


COMPARISON_FIELDS = ("schema", "runtime", "os", "arch", "jit", "clock")
FIELD_LABELS = {
    "schema": "report format",
    "runtime": "runtime",
    "os": "operating system",
    "arch": "architecture",
    "jit": "JIT mode",
    "clock": "clock source",
}


def comparison_mismatch(data, previous):
    """Return why two benchmark reports cannot be compared, or None."""
    for field in COMPARISON_FIELDS:
        if data[field] != previous[field]:
            return FIELD_LABELS[field]
    if {case["name"] for case in data["cases"]} != {case["name"] for case in previous["cases"]}:
        return "set of scenarios"
    return None


def benchmarks(path, baseline):
    print("## Lua benchmarks\n")
    if not path.exists():
        print("❌ No benchmark report was produced. See the benchmark step for details.")
        return
    data = json.loads(path.read_text())
    previous = None
    if baseline is not None and baseline.exists():
        candidate = json.loads(baseline.read_text())
        mismatch = comparison_mismatch(data, candidate)
        if mismatch:
            print(f"> ⚠️ Baseline ignored: it was recorded with a different {mismatch}. "
                  "Only results produced the same way are compared.\n")
        else:
            previous = candidate
    old = {case["name"]: case for case in previous["cases"]} if previous else {}
    print(f"{cell(data['runtime'])} · {cell(data['os'])}/{cell(data['arch'])} · JIT {'on' if data['jit'] else 'off'}\n")
    print(f"Revision: `{data['revision']}`{' (working tree modified)' if data['dirty'] else ''}.\n")
    if previous:
        print(f"Baseline: `{previous['revision']}`{' (working tree modified)' if previous['dirty'] else ''}.\n")
    print("CPU time per operation; lower is better. Nine warmed samples, normal GC enabled.\n")
    print("| Scenario | Median ns/op | Min–max ns/op | Change vs baseline |\n| :--- | ---: | ---: | ---: |")
    for case in data["cases"]:
        samples = case["ns_per_op"]
        median = statistics.median(samples)
        change = "—"
        if case["name"] in old:
            before = statistics.median(old[case["name"]]["ns_per_op"])
            change = f"{(median / before - 1) * 100:+.1f}%"
        print(f"| {cell(case['name'])} | {median:.1f} | {min(samples):.1f}–{max(samples):.1f} | {change} |")
    print("\nReal mod methods with simulated game APIs; includes loop and fixture overhead. "
          "These are not frame times or FPS estimates. Compare on the same machine with the same harness; "
          "shared CI runners can vary. No performance pass/fail threshold is applied.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("tests", "benchmarks"))
    parser.add_argument("report", type=Path)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    if args.kind == "tests":
        tests(args.report)
    else:
        benchmarks(args.report, args.baseline)
