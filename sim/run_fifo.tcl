set fifo_signals [get_objects -quiet /tb_sync_fifo/dut/*]
if {[llength $fifo_signals] == 0} {
    set fifo_signals [get_objects -quiet /*/test_fifo/dut/*]
}
if {[llength $fifo_signals] > 0} {
    log_wave $fifo_signals
}
run all
quit
