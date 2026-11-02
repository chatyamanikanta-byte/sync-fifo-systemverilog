#!/usr/bin/env python3

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


def main():
    LOGS.mkdir(parents=True, exist_ok=True)

    build_commands = [
        (
            ["xvlog", "--sv", "../rtl/sync_fifo.sv",
             "../tb/tb_sync_fifo.sv"],
            "compile.log",
        ),
        (
            ["xelab", "tb_sync_fifo", "-s",
             "fifo_regression_sim", "--debug", "typical"],
            "elaborate.log",
        ),
    ]

    for command, filename in build_commands:
        code, output = run_logged(command, LOGS / filename)

        if code != 0 or re.search(r"^\s*ERROR:", output, re.MULTILINE):
            print("BUILD FAILED. See:", LOGS / filename)
            return 1

    failures = 0
    summary = ["seed,status,checked_cycles"]

    for seed in SEEDS:
        log_path = LOGS / ("seed_{}.log".format(seed))

        code, output = run_logged(
            [
                "xsim", "fifo_regression_sim",
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

    (LOGS / "summary.csv").write_text("\n".join(summary) + "\n")

    print("\nResult: {}/{} seeds passed".format(
        len(SEEDS) - failures, len(SEEDS)
    ))
    print("Summary:", LOGS / "summary.csv")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
