#!/usr/bin/env python3

import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
SIM = ROOT / "sim"
LOGS = SIM / "regression_logs"
SEEDS = [1, 42, 184, 2026, 9999]


def run_logged(command, log_path):
    print("Running:", " ".join(command), flush=True)

    with log_path.open("w") as output:
        result = subprocess.run(
            command,
            cwd=str(SIM),
            stdout=output,
            stderr=subprocess.STDOUT,
        )

    return result.returncode, log_path.read_text(errors="replace")


def run_configuration(top, logs):
    logs.mkdir(parents=True, exist_ok=True)
    snapshot = top + "_regression_sim"
    code, output = run_logged(
        ["xelab", top, "-s", snapshot, "--debug", "typical"],
        logs / "elaborate.log",
    )
    if code != 0 or re.search(r"^\s*ERROR:", output, re.MULTILINE):
        print("ELABORATION FAILED. See:", logs / "elaborate.log")
        return 1

    failures = 0
    summary = ["seed,status,checked_cycles"]

    for seed in SEEDS:
        log_path = logs / ("seed_{}.log".format(seed))

        code, output = run_logged(
            [
                "xsim", snapshot,
                "-sv_seed", str(seed),
                "-tclbatch", "run_fifo.tcl",
            ],
            log_path,
        )

        match = re.search(
            r"PASS: synchronous FIFO passed (\d+) checked cycles\.",
            output,
        )
        has_error = re.search(
            r"^\s*(?:Fatal:|ERROR:|FATAL:)", output, re.MULTILINE
        )

        passed = code == 0 and match is not None and has_error is None
        status = "PASS" if passed else "FAIL"
        cycles = match.group(1) if match else ""

        summary.append("{},{},{}".format(seed, status, cycles))
        print("Seed {}: {} ({} cycles)".format(seed, status, cycles))

        if not passed:
            failures += 1
            print("  Inspect:", log_path)

    (logs / "summary.csv").write_text("\n".join(summary) + "\n")

    print("\nResult: {}/{} seeds passed".format(
        len(SEEDS) - failures, len(SEEDS)
    ))
    print("Summary:", logs / "summary.csv")

    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description="Run the FIFO XSim regression.")
    parser.add_argument("--matrix", action="store_true",
                        help="also test depths 1 and 5")
    args = parser.parse_args()

    LOGS.mkdir(parents=True, exist_ok=True)
    compile_log = LOGS / "compile.log"
    code, output = run_logged(
        ["xvlog", "--sv", "../rtl/sync_fifo.sv", "../tb/tb_sync_fifo.sv"],
        compile_log,
    )
    if code != 0 or re.search(r"^\s*ERROR:", output, re.MULTILINE):
        print("COMPILE FAILED. See:", compile_log)
        return 1

    configurations = [("tb_sync_fifo", LOGS)]
    if args.matrix:
        configurations.extend([
            ("tb_sync_fifo_depth1", LOGS / "depth1"),
            ("tb_sync_fifo_depth5", LOGS / "depth5"),
        ])

    failed = False
    for top, logs in configurations:
        print("\nConfiguration:", top)
        failed |= bool(run_configuration(top, logs))
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
