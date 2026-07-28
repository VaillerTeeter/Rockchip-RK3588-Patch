#!/usr/bin/env python3
"""
Filter AOSP build.log by module path, extracting complete warning/error blocks.

A "block" is defined as: one or more consecutive warning/error lines belonging to
the same source file, delimited by the next warning/error header line
(e.g. "path/file.c:line:col: warning: ..." or "path/file.c:line:col: error: ...").

The script preserves:
  - Warning/error header lines
  - Associated source context lines (code + caret)
  - File-level summary lines ("N warning(s) generated.", "N error(s) generated.")

Usage:
  # Extract warnings for a specific module
  ./filter-build-log.py build.log external/can-utils > can-utils-warnings.txt

  # Extract all warnings under external/
  ./filter-build-log.py build.log external/ > all-external.txt

  # Show module-level warning/error counts
  ./filter-build-log.py build.log --stats
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

# Regex to match warning/error header lines
# e.g. "external/can-utils/cansequence.c:73:29: warning: unused parameter 'signo' [-Wunused-parameter]"
HEADER_RE = re.compile(
    r'^[^:\s]+:\d+:\d+:\s+(warning|error):\s+'
)

# Summary lines after a file's warnings/errors
# e.g. "1 warning generated.", "2 errors generated."
SUMMARY_RE = re.compile(
    r'^\d+\s+(warning|error)s?\s+generated\.'
)


def is_header(line: str) -> bool:
    """Return True if line is a warning/error header."""
    # Quick pre-check: must contain ': warning:' or ': error:'
    if ': warning:' not in line and ': error:' not in line:
        return False
    return bool(HEADER_RE.match(line))


def is_summary(line: str) -> bool:
    """Return True if line is a file-level summary."""
    return bool(SUMMARY_RE.match(line))


def match_filter(header_line: str, pattern: str) -> bool:
    """Check if a header line's source path contains the pattern."""
    # Extract path part (before the first ":line:" part)
    # e.g. "external/can-utils/foo.c:73:29: warning: ..." -> path = "external/can-utils/foo.c"
    idx = header_line.find(':')
    if idx == -1:
        return False
    path_part = header_line[:idx]
    return pattern in path_part


def split_blocks(
    lines: list[str], pattern: str
) -> tuple[list[str], list[str]]:
    """Split lines into (matched_blocks, remaining_lines).

    Matched blocks (headers that match pattern + their body + summary) are
    collected separately. Everything else goes into remaining_lines.
    """
    matched: list[str] = []
    remaining: list[str] = []
    in_block = False

    for line in lines:
        if is_header(line):
            in_block = match_filter(line, pattern)
            if in_block:
                matched.append(line)
                continue
        elif is_summary(line):
            if in_block:
                matched.append(line)
                in_block = False
                continue
        else:
            if in_block:
                matched.append(line)
                continue

        remaining.append(line)

    return matched, remaining


def collect_blocks(lines: list[str], pattern: str) -> list[str]:
    """Collect all warning/error blocks whose headers match the pattern."""
    matched, _ = split_blocks(lines, pattern)
    return matched


def compute_stats(lines: list[str]) -> list[tuple[str, int]]:
    """Count warnings/errors per source file path prefix."""
    counts: dict[str, int] = defaultdict(int)

    for line in lines:
        if is_header(line):
            # Extract path before the first ":"
            idx = line.find(':')
            if idx != -1:
                path_part = line[:idx]
                counts[path_part] += 1

    # Sort by count descending
    return sorted(counts.items(), key=lambda x: x[1], reverse=True)


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)

    log_path = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) >= 3 else ""

    if not Path(log_path).exists():
        print(f"Error: file not found: {log_path}", file=sys.stderr)
        sys.exit(1)

    with open(log_path, 'r', errors='replace') as f:
        lines = f.readlines()

    if mode == "--stats":
        stats = compute_stats(lines)
        print(f"{'Count':>6}  {'File'}")  # English header to avoid encoding issues
        print(f"{'-----':>6}  {'----'}")
        for path, count in stats:
            print(f"{count:>6}  {path}")
        return

    # Parse remaining args: "pattern [--cut]"
    args = sys.argv[2:]
    cut = False
    pattern = None

    for arg in args:
        if arg == "--cut":
            cut = True
        elif arg == "--stats":
            # This branch is handled above, but keep for robustness
            pass
        else:
            pattern = arg

    if pattern is None:
        print("Error: filter pattern required (or use --stats)", file=sys.stderr)
        sys.exit(1)

    if cut:
        matched, remaining = split_blocks(lines, pattern)
        if not matched:
            print(f"No warnings/errors found matching '{pattern}'", file=sys.stderr)
            sys.exit(0)
        # Write remaining lines back to the original log file
        with open(log_path, 'w') as f:
            for line in remaining:
                f.write(line)
        print(
            f"Removed {len(matched)} lines matching '{pattern}' from {log_path}",
            file=sys.stderr,
        )
        for line in matched:
            sys.stdout.write(line)
    else:
        result = collect_blocks(lines, pattern)
        if not result:
            print(f"No warnings/errors found matching '{pattern}'", file=sys.stderr)
            sys.exit(0)
        for line in result:
            sys.stdout.write(line)


if __name__ == "__main__":
    main()