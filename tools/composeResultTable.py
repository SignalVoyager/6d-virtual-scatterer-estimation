from __future__ import annotations

"""
Result Table Composer Module

This module aggregates experiment metrics from `.log` files into CSV tables.
It follows the same workflow style as `composeFigurePanel.m`:
1. Use the current working directory as `rootDir`, or pass one on the CLI.
2. Parse `rootDir` directly when it contains `.log` files; otherwise iterate over
   subfolders under `rootDir` (or a configured subset).
3. Export summary tables back into the folder that owns the input logs.

Configuration (inside `composeResultTable`):
    rootDir (Path):
        Root folder that contains log files or experiment subfolders. Default is
        the current working directory.
    targetSubfolders (list[str]):
        Subfolder whitelist. Empty list means processing all subfolders.
    fileOrder (list[str]):
        Optional preferred log-file order within each subfolder. Files not listed
        are appended afterward in alphabetical order.
    outputName (str):
        Base name for generated CSV files:
        - <outputName>_details.csv
        - <outputName>_average.csv

Input log format assumptions:
    - Experiment blocks start with a line like:
      "======== EXP: <name> | SEED: <n> ========"
    - Metric lines begin with "[Eval]" and contain key-value tokens such as
      "RMSE=0.123" or "corr(y,yhat)=0.98".
    - Optional bucket lines are parsed when a Buckets section appears.

Outputs per subfolder:
    - Detailed record table with one row per experiment run.
    - Average/std table with one row per metric.

Run:
    python tools/composeResultTable.py docs/S_Fig1_intuitive/source_logs
"""

import argparse
import csv
import math
import re
from collections import defaultdict
from pathlib import Path
from statistics import mean, pstdev
from typing import Dict, List, Sequence


_EXP_PATTERN = re.compile(r"={8,}\s*EXP:\s*(.*?)\s*\|\s*SEED:\s*(\d+)\s*={8,}")
_KV_PATTERN = re.compile(
    r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)"
)
_COMPLEX_KV_PATTERN = re.compile(
    r"([A-Za-z_][A-Za-z0-9_]*\([^)]+\))\s*=\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)"
)
_BUCKET_PATTERN = re.compile(
    r"([A-Z]+)\s+\([^)]+\):\s+MSE=([\d.eE+-]+),\s+NMSE=([\d.eE+-]+),\s+count=(\d+)"
)
_SCORE100_PATTERN = re.compile(r"Score100=([\d.]+)/100")


def composeResultTable(root_dir: Path | str | None = None) -> None:
    """
    Entry point for batch log aggregation.

    This function discovers subfolders under `rootDir`, parses each folder's
    `.log` files, and writes composed CSV outputs into that same subfolder.

    Raises:
        FileNotFoundError: If `rootDir` does not exist.
        RuntimeError: If no subfolders are found under `rootDir`.
    """
    cfg = {
        "rootDir": Path.cwd() if root_dir is None else Path(root_dir),
        "targetSubfolders": [],
        "fileOrder": [],
        "outputName": "result_aggregated",
    }

    root_dir = Path(cfg["rootDir"])
    if not root_dir.is_dir():
        raise FileNotFoundError(f"Root directory does not exist: {root_dir}")

    processed_count = 0
    root_log_list = collectLogList(root_dir, cfg["fileOrder"], cfg["outputName"])
    sub_dirs = [root_dir] if root_log_list else listTargetSubfolders(
        root_dir, cfg["targetSubfolders"]
    )
    if not sub_dirs:
        raise RuntimeError(f"No log folders found under {root_dir}")

    for sub_dir in sub_dirs:
        if sub_dir == root_dir and root_log_list:
            log_list = root_log_list
        else:
            log_list = collectLogList(sub_dir, cfg["fileOrder"], cfg["outputName"])
        if not log_list:
            print(f"[composeResultTable] skip {sub_dir} (no .log files).")
            continue
        composeOneFolder(log_list, cfg, sub_dir)
        processed_count += 1

    print(f"[composeResultTable] done. root={root_dir}, subfolders={processed_count}")


def composeOneFolder(log_list: Sequence[Path], cfg: Dict[str, object], sub_dir: Path) -> None:
    """
    Aggregate all logs in one subfolder and write CSV outputs.

    Args:
        log_list: Ordered list of log files to parse.
        cfg: Runtime configuration dictionary. Uses `outputName` for output naming.
        sub_dir: Target subfolder currently being processed.
    """
    records: List[Dict[str, object]] = []
    metric_values: Dict[str, List[float]] = defaultdict(list)

    for log_path in log_list:
        experiments = parseLogFile(log_path)
        if not experiments:
            print(f"[composeResultTable] warning: no experiments found in {log_path.name}")
            continue

        for exp in experiments:
            row: Dict[str, object] = {
                "log_file": log_path.name,
                "exp_name": exp["exp_name"],
                "seed": exp["seed"],
            }
            for key, value in exp["metrics"].items():
                row[key] = value
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    metric_values[key].append(float(value))
            records.append(row)

    if not records:
        print(f"[composeResultTable] warning: skip {sub_dir} (no valid experiment records).")
        return

    averages = {k: mean(v) for k, v in metric_values.items() if v}
    stds = {
        k: (pstdev(v) if len(v) > 1 else 0.0)
        for k, v in metric_values.items()
        if v
    }

    output_base = sub_dir / str(cfg["outputName"])
    saveDetailCsv(records, output_base.with_name(output_base.name + "_details.csv"))
    saveAverageCsv(averages, stds, output_base.with_name(output_base.name + "_average.csv"))

    print(
        f"[composeResultTable] subfolder={sub_dir}, logs={len(log_list)}, "
        f"records={len(records)}, output={output_base}"
    )


def listTargetSubfolders(root_dir: Path, target_subfolders: Sequence[str]) -> List[Path]:
    """
    Resolve subfolders to process under `root_dir`.

    Args:
        root_dir: Root folder containing candidate subfolders.
        target_subfolders: Case-insensitive whitelist. Empty means all subfolders.

    Returns:
        List of resolved subfolder paths in deterministic order.
    """
    names = [p.name for p in root_dir.iterdir() if p.is_dir()]
    names.sort(key=str.lower)

    if not target_subfolders:
        picks = names
    else:
        lower_to_name = {name.lower(): name for name in names}
        picks = []
        for req in target_subfolders:
            hit = lower_to_name.get(str(req).lower())
            if hit is None:
                print(f"[composeResultTable] warning: targetSubfolders item not found: {req}")
            else:
                picks.append(hit)

    return [root_dir / name for name in picks]


def collectLogList(source_dir: Path, file_order: Sequence[str], output_name: str) -> List[Path]:
    """
    Collect and order `.log` files from one subfolder.

    Args:
        source_dir: Folder to scan for log files.
        file_order: Optional preferred file order (with or without `.log` suffix).
        output_name: Output base name used to avoid selecting generated files.

    Returns:
        Ordered list of `.log` files to parse.
    """
    all_logs = sorted(source_dir.glob("*.log"), key=lambda p: p.name.lower())
    if not all_logs:
        return []

    output_stem = output_name.lower()
    filtered_logs = [
        p
        for p in all_logs
        if p.stem.lower() != output_stem
        and not p.name.lower().startswith(f"{output_stem}_")
    ]
    if not filtered_logs:
        return []

    if not file_order:
        return filtered_logs

    name_to_path = {p.name.lower(): p for p in filtered_logs}
    ordered: List[Path] = []
    used = set()

    for item in file_order:
        name = str(item)
        if not name.lower().endswith(".log"):
            name += ".log"
        path = name_to_path.get(name.lower())
        if path is None:
            print(f"[composeResultTable] warning: file in fileOrder not found: {name}")
            continue
        ordered.append(path)
        used.add(path.name.lower())

    for path in filtered_logs:
        if path.name.lower() not in used:
            ordered.append(path)
    return ordered


def parseLogFile(filepath: Path) -> List[Dict[str, object]]:
    """
    Parse one log file into structured experiment records.

    Args:
        filepath: Path to a UTF-8 text log file.

    Returns:
        A list of experiment dictionaries:
        {
            "exp_name": str,
            "seed": int,
            "metrics": dict[str, float|int]
        }
    """
    experiments: List[Dict[str, object]] = []
    current_exp: Dict[str, object] | None = None

    lines = filepath.read_text(encoding="utf-8", errors="ignore").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        exp_match = _EXP_PATTERN.search(line)
        if exp_match:
            if current_exp is not None:
                experiments.append(current_exp)
            current_exp = {
                "exp_name": exp_match.group(1),
                "seed": int(exp_match.group(2)),
                "metrics": {},
            }
            i += 1
            continue

        if current_exp is not None and line.startswith("[Eval]"):
            metrics = current_exp["metrics"]
            _extractSimpleMetrics(line, metrics)
            _extractComplexMetrics(line, metrics)
            _extractScore100(line, metrics)
            if "Buckets" in line:
                i = _extractBuckets(lines, i, metrics)

        i += 1

    if current_exp is not None:
        experiments.append(current_exp)
    return experiments


def _extractSimpleMetrics(line: str, metrics: Dict[str, object]) -> None:
    """Extract plain `key=value` numeric metrics from one `[Eval]` line."""
    for key, value in _KV_PATTERN.findall(line):
        try:
            metrics[key] = float(value)
        except ValueError:
            continue


def _extractComplexMetrics(line: str, metrics: Dict[str, object]) -> None:
    """Extract function-style metrics (e.g., `corr(y,yhat)=...`) and normalize keys."""
    for key, value in _COMPLEX_KV_PATTERN.findall(line):
        try:
            left, right = key.split("(", 1)
            normalized = f"{left}_{right.rstrip(')').replace(',', '_')}"
            metrics[normalized] = float(value)
        except (ValueError, IndexError):
            continue


def _extractScore100(line: str, metrics: Dict[str, object]) -> None:
    """Extract `Score100=x/100` metric if present."""
    match = _SCORE100_PATTERN.search(line)
    if match:
        try:
            metrics["Score100"] = float(match.group(1))
        except ValueError:
            pass


def _extractBuckets(lines: Sequence[str], start_idx: int, metrics: Dict[str, object]) -> int:
    """
    Parse consecutive bucket lines following a Buckets marker line.

    Args:
        lines: Full log lines.
        start_idx: Index of the Buckets marker line.
        metrics: Destination metrics dictionary.

    Returns:
        Updated line index position consumed by bucket parsing.
    """
    j = start_idx + 1
    while j < len(lines) and lines[j].strip().startswith("[Eval]"):
        bucket_line = lines[j].strip()
        match = _BUCKET_PATTERN.search(bucket_line)
        if match:
            bucket = match.group(1).lower()
            metrics[f"bucket_{bucket}_MSE"] = float(match.group(2))
            metrics[f"bucket_{bucket}_NMSE"] = float(match.group(3))
            metrics[f"bucket_{bucket}_count"] = int(match.group(4))
        j += 1
    return j - 1


def saveDetailCsv(records: Sequence[Dict[str, object]], out_path: Path) -> None:
    """
    Save per-experiment detailed rows to CSV.

    Args:
        records: Row dictionaries from parsed experiments.
        out_path: Output CSV path.
    """
    fieldnames = sorted({k for row in records for k in row.keys()})
    preferred = ["log_file", "exp_name", "seed"]
    fieldnames = [f for f in preferred if f in fieldnames] + [
        f for f in fieldnames if f not in preferred
    ]

    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in records:
            writer.writerow(row)


def saveAverageCsv(averages: Dict[str, float], stds: Dict[str, float], out_path: Path) -> None:
    """
    Save metric average/std table to CSV.

    Args:
        averages: Metric average values.
        stds: Metric population standard deviations.
        out_path: Output CSV path.
    """
    rows = []
    for key in sorted(averages):
        avg = averages[key]
        std = stds.get(key, 0.0)
        rows.append({"metric": key, "average": _safeFloat(avg), "std_dev": _safeFloat(std)})

    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["metric", "average", "std_dev"])
        writer.writeheader()
        writer.writerows(rows)


def _safeFloat(value: float) -> float:
    """Clamp NaN/Inf to 0.0 for CSV-safe output."""
    if math.isnan(value) or math.isinf(value):
        return 0.0
    return float(value)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Aggregate experiment metrics from .log files into CSV tables."
    )
    parser.add_argument(
        "root_dir",
        nargs="?",
        default=None,
        help="Folder containing log subfolders. Defaults to the current working directory.",
    )
    args = parser.parse_args()
    composeResultTable(args.root_dir)
