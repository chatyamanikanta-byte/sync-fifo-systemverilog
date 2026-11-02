# Synchronous FIFO

Handwritten SystemVerilog FIFO: 8-bit data, eight entries,
single clock, synchronous active-high reset, registered read output.

## Boundary behavior

- Writes while full are rejected.
- Reads while empty are rejected.
- Simultaneous requests while empty accept only the write.
- Simultaneous requests while full accept only the read.
- Simultaneous requests at intermediate occupancy accept both.

## Run on hunmin

Load Vivado in tcsh:

```tcsh
source /apps/Xilinx/Vivado/2022.2/settings64.csh
python3 run_regression.py
```

Requires Python 3 and Vivado Simulator 2022.2.

## Verification evidence

- Independent queue scoreboard checks data, occupancy and flags.
- Immediate assertions check occupancy, pointer updates and reset output.
- Five random seeds passed: 1, 42, 184, 2026, 9999.
- Total: 3,016 checked cycles across the five runs.
- Intentional write-pointer fault detected at 36 ns.

Each seed repeats the directed suite before 500 randomized cycles.
These results are simulation evidence; functional coverage and FPGA
implementation are not yet completed.

The intentionally faulty RTL is isolated in fault_test and excluded
from the normal regression.
