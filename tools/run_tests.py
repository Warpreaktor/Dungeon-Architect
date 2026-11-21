#!/usr/bin/env python3
"""Run Godot SceneTree test scripts in isolated processes."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ERROR_PATTERN = re.compile(r"(?im)^\s*(?:SCRIPT ERROR:|ERROR:|Assertion failed:|ASSERTION FAILED:)")


def discover(root: Path, pattern: str) -> list[Path]:
    return sorted(path for path in (root / "tests").rglob("test_*.gd")
                  if pattern.lower() in path.name.lower())


def run_test(godot: str, root: Path, path: Path, timeout: float) -> tuple[str, float, str]:
    relative = path.relative_to(root).as_posix()
    command = [godot, "--headless", "--path", str(root), "--script", f"res://{relative}"]
    start = time.monotonic()
    try:
        process = subprocess.run(command, cwd=root, capture_output=True, text=True,
                                 errors="replace", timeout=timeout, check=False)
        output = process.stdout + process.stderr
        failed = process.returncode != 0 or bool(ERROR_PATTERN.search(output))
        status = "FAIL" if failed else "PASS"
        if process.returncode != 0:
            output += f"\nExit code: {process.returncode}"
    except subprocess.TimeoutExpired as exc:
        status = "TIMEOUT"
        output = f"Exceeded {timeout:g}s timeout\n{exc.stdout or b''}\n{exc.stderr or b''}"
    except OSError as exc:
        status = "ERROR"
        output = str(exc)
    return status, time.monotonic() - start, str(output)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run all Godot tests in separate headless processes")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"),
                        help="Godot executable (or GODOT_BIN environment variable)")
    parser.add_argument("--timeout", type=float, default=60.0, help="Timeout per test in seconds")
    parser.add_argument("--filter", default="", help="Part of test filename")
    parser.add_argument("--check-order", action="store_true", help="Run again in reverse order")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1],
                        help="Godot project root")
    args = parser.parse_args(argv)
    root = args.project.resolve()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if not (root / "project.godot").is_file():
        print(f"Missing project.godot: {root}", file=sys.stderr)
        return 2
    godot = shutil.which(args.godot) or (str(Path(args.godot).resolve()) if Path(args.godot).is_file() else None)
    if godot is None:
        print(f"Godot executable not found: {args.godot}", file=sys.stderr)
        return 2
    tests = discover(root, args.filter)
    if not tests:
        print("No matching tests found", file=sys.stderr)
        return 2
    results: list[tuple[str, str, float, str]] = []
    runs = (tests, list(reversed(tests))) if args.check_order else (tests,)
    for pass_index, batch in enumerate(runs, start=1):
        if len(runs) > 1:
            print(f"\nRun {pass_index}/{len(runs)} ({'forward' if pass_index == 1 else 'reverse'})", flush=True)
        for path in batch:
            status, duration, output = run_test(godot, root, path, args.timeout)
            name = path.relative_to(root).as_posix()
            results.append((name, status, duration, output))
            print(f"[{status:7}] {name} ({duration:.2f}s)", flush=True)
            if status != "PASS":
                for line in output.rstrip().splitlines()[-25:]:
                    print(f"    {line}", flush=True)
    passed = sum(status == "PASS" for _, status, _, _ in results)
    failed = len(results) - passed
    print(f"\nResult: {passed} passed, {failed} failed, {len(results)} runs", flush=True)
    if args.check_order:
        first = {name: status for name, status, _, _ in results[:len(tests)]}
        second = {name: status for name, status, _, _ in results[len(tests):]}
        differing = [name for name in first if first[name] != second[name]]
        if differing:
            print("Order-dependent results: " + ", ".join(differing), flush=True)
            return 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
