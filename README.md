# Synchronous FIFO

SystemVerilog FIFO with configurable positive `DATA_WIDTH` and `DEPTH`
parameters. The defaults are 8-bit data and eight entries. The FIFO uses a
single clock, synchronous active-high reset, and a registered read output.

## Boundary behavior

- Writes while full are rejected.
- Reads while empty are rejected.
- Simultaneous requests while empty accept only the write.
- Simultaneous requests while full accept only the read.
- Simultaneous requests at intermediate occupancy accept both.

Operations use the occupancy before the rising edge. Read data updates
after an accepted read, clears on reset, and otherwise holds its value.
Each pointer wraps from address `DEPTH - 1` to zero.

## Run on hunmin

From the repository root, load Vivado Simulator 2022.2 in tcsh and
run the three-configuration regression with Python 3:

```tcsh
source /apps/Xilinx/Vivado/2022.2/settings64.csh
python3 run_regression.py --matrix
```

Use `python3 run_regression.py` for the default configuration only.

| Data width | Depth | Required occupancy × request bins | Logs under `sim/regression_logs/` |
|---:|---:|---:|---|
| 8 | 8 | 36 | `.` |
| 1 | 1 | 8 | `depth1/` |
| 16 | 5 | 24 | `depth5/` |

Each configuration runs a queue scoreboard, occupancy and pointer
assertions, directed tests, and 500 randomized transactions per seed.
A deterministic sweep exercises every combination of pre-transaction
occupancy and read/write requests. Each seed must hit all applicable
bins before reporting PASS. Each log directory contains a `summary.csv`.

## Parameterized simulation results

Verilator 5.48 ran the same SystemVerilog testbench with assertions
enabled for seeds 1, 42, 184, 2026, and 9999.

| Data width | Depth | Seeds passed | Checked cycles | Cross bins per seed |
|---:|---:|---:|---:|---:|
| 1 | 1 | 5/5 | 2,738 | 8/8 |
| 16 | 5 | 5/5 | 3,405 | 24/24 |
| 8 | 8 | 5/5 | 4,099 | 36/36 |

### Vivado Simulator 2022.2 on hunmin

The same five seeds passed in XSim for each configuration.

| Data width | Depth | Seeds passed | Checked cycles | Cross bins per seed |
|---:|---:|---:|---:|---:|
| 1 | 1 | 5/5 | 2,737 | 8/8 |
| 16 | 5 | 5/5 | 3,397 | 24/24 |
| 8 | 8 | 5/5 | 4,092 | 36/36 |
| | **Total** | **15/15** | **10,226** | |

A passing run requires all applicable cross-coverage bins, along with
passing scoreboard and assertion checks.

## Historical baseline evidence

The fixed 8-bit, eight-entry FIFO at commit `3ca7048` passed all five
XSim seeds (1, 42, 184, 2026, 9999) for **4,101 checked cycles** and
**36/36 cross-coverage bins** in every seed.

- [Regression summary](docs/evidence/regression_summary.csv)
- [Coverage log for seed 184](docs/evidence/coverage_seed184.log)
- [Write-pointer fault analysis](docs/debug_pointer_fault.md)

The isolated write-pointer fault was detected at 36 ns. The faulty RTL
lives in `fault_test/` and is excluded from the normal regression.

## Two-requester round-robin arbiter

`rtl/round_robin_arbiter.sv` selects one of two requests with a one-hot
`grant`. The downstream interface accepts the selected request at a
rising edge when `ready` is high and a grant is asserted. Requesters
hold their requests and payloads until accepted. A stalled grant holds
its selection until acceptance or reset. Each accepted transfer gives
the other requester priority on the next arbitration.

Active-high reset suppresses grants and synchronously clears the held
selection. Requester 0 gets priority on the first tie after reset.
The arbiter supplies the selection. The caller uses it to select payloads.

From the repository root, with Vivado Simulator 2022.2 loaded:

```bash
cd sim
xvlog --sv ../rtl/round_robin_arbiter.sv ../tb/tb_round_robin_arbiter.sv
xelab tb_round_robin_arbiter -s arbiter_sim
xsim arbiter_sim -runall
```

The self-checking testbench covers idle, both single-request cases,
sustained contention, a new request arriving during a stall, resumption
after a stall, and reset during a stall.

The directed regression passed in Verilator and Vivado Simulator 2022.2
on hunmin, with **31 checked cycles** and **21 accepted transfers** in
each simulator. The XSim run finished at 315 ns.

## Ready/valid skid buffer

`rtl/ready_valid_skid_buffer.sv` uses one storage slot and a bypass
path. When empty, it accepts an input beat and presents it at the
output in the same cycle. If downstream stalls, it saves the beat and
holds it at the output until delivery. The input stays backpressured
while the slot is full, including the edge that drains the slot.
Active-high reset suppresses handshakes and clears the slot on the
rising edge. The data width defaults to 8 bits and is configurable.

The directed test passed in Icarus Verilog using 16-bit data. It checked
14 cycles, accepted 6 beats, and delivered 5 beats. Reset flushed the
remaining beat.

From the repository root, with Vivado Simulator 2022.2 loaded:

```bash
cd sim
xvlog --sv ../rtl/ready_valid_skid_buffer.sv ../tb/tb_ready_valid_skid_buffer.sv
xelab tb_ready_valid_skid_buffer -s skid_buffer_sim
xsim skid_buffer_sim -runall
```
