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


def reference_median(report):
    reference = report.get("reference")
    if reference and reference.get("ns_per_op"):
        return statistics.median(reference["ns_per_op"])
    return None


def relative(case, reference):
    """Cost relative to the reference workload, so machines can be compared."""
    value = statistics.median(case["ns_per_op"])
    return value / reference if reference else value


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

    print(f"{cell(data['runtime'])} · {cell(data['os'])}/{cell(data['arch'])} · JIT {'on' if data['jit'] else 'off'}\n")
    print(f"Revision: `{data['revision']}`{' (working tree modified)' if data['dirty'] else ''}.\n")
    if previous:
        print(f"Baseline: `{previous['revision']}`{' (working tree modified)' if previous['dirty'] else ''}.\n")
    reference = reference_median(data)
    baseline_reference = reference_median(previous) if previous else None
    if reference:
        note = f"Reference workload: {reference:.1f} ns/op"
        if baseline_reference:
            note += f" (baseline {baseline_reference:.1f} ns/op)"
        print(f"{note}. Changes are normalised by it, so they stay meaningful across machines.\n")

    print("| Scenario | Runs | ns/op | min–max | bytes/op | Change vs baseline |\n"
          "| :--- | :--- | ---: | ---: | ---: | ---: |")
    old = {case["name"]: case for case in previous["cases"]} if previous else {}
    for case in data["cases"]:
        samples = case["ns_per_op"]
        median = statistics.median(samples)
        spread = f"{min(samples):.1f}–{max(samples):.1f}"
        bytes_per_op = case.get("bytes_per_op")
        byte_text = "—" if bytes_per_op is None else f"{bytes_per_op:.1f}"
        change = "—"
        if case["name"] in old:
            before = relative(old[case["name"]], baseline_reference)
            if before:
                change = f"{(relative(case, reference) / before - 1) * 100:+.1f}%"
        print(f"| {cell(case['name'])} | {cell(case.get('runs', '—'))} | {median:.1f} | "
              f"{spread} | {byte_text} | {change} |")

    interpreted = [case for case in data["cases"] if case.get("ns_per_op_interpreted")]
    if interpreted:
        print("\n<details><summary>Worst case with the JIT disabled (ns/op)</summary>\n")
        print("| Scenario | JIT on | JIT off |\n| :--- | ---: | ---: |")
        for case in interpreted:
            print(f"| {cell(case['name'])} | {statistics.median(case['ns_per_op']):.1f} | "
                  f"{statistics.median(case['ns_per_op_interpreted']):.1f} |")
        print("\n</details>")

    print("\nReal mod methods with simulated game APIs. `Runs` marks whether a scenario is charged "
          "**per frame** (once each update) or **per input query** (the engine issues many queries "
          "per frame). `bytes/op` is allocation with the collector paused, i.e. GC pressure. "
          "These are not frame times or FPS estimates, and no pass/fail threshold is applied.")
    frame_cases = [case for case in data["cases"] if case.get("runs") == "frame"]
    if frame_cases:
        worst = max(frame_cases, key=lambda item: statistics.median(item["ns_per_op"]))
        cost = statistics.median(worst["ns_per_op"])
        print(f"\nFor scale, the heaviest per-frame scenario ({cell(worst['name'])}) is "
              f"{cost:.0f} ns/frame, about {cost / 16666667 * 100:.4f}% of a 16.7 ms (60 fps) budget.")




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
