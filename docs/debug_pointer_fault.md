# Write-pointer fault injection

## Baseline
Original RTL passed 602 checked cycles with seed 184,
with no assertion failures.

## Injected fault
In fault_test/sync_fifo_fault.sv, changed the write-pointer
increment from 1 to 2.

## Observed result
The a_write_pointer assertion failed at 36 ns, immediately
after the first accepted write.

## Root cause
The write pointer skipped a memory location while occupancy
still increased by one.

## Conclusion
The pointer assertion detected this injected fault.
The original RTL in rtl/sync_fifo.sv was unchanged.
