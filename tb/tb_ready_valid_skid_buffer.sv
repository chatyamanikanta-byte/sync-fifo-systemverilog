`timescale 1ns/1ps

module tb_ready_valid_skid_buffer;
    logic clk = 1'b0;
    logic rst, in_valid, in_ready, out_valid, out_ready;
    logic [15:0] in_data, out_data;
    int cycles = 0;
    int accepted = 0;
    int delivered = 0;

    always #5 clk = !clk;

    ready_valid_skid_buffer #(.DATA_WIDTH(16)) dut (.*);

    task automatic step(
        input logic reset, valid, ready,
        input logic [15:0] data,
        input logic expected_in_ready, expected_out_valid,
        input logic [15:0] expected_data
    );
        @(negedge clk);
        rst = reset;
        in_valid = valid;
        out_ready = ready;
        in_data = data;

        @(posedge clk);
        cycles++;
        if (in_ready !== expected_in_ready ||
            out_valid !== expected_out_valid ||
            (expected_out_valid && out_data !== expected_data))
            $fatal(1, "Cycle %0d: expected ready/valid/data %b/%b/%h, got %b/%b/%h",
                   cycles, expected_in_ready, expected_out_valid, expected_data,
                   in_ready, out_valid, out_data);
        if (in_valid && in_ready)
            accepted++;
        if (out_valid && out_ready)
            delivered++;
    endtask

    initial begin
        rst = 1'b1;
        in_valid = 1'b0;
        in_data = '0;
        out_ready = 1'b0;

        step(1, 1, 1, 16'hFFFF, 0, 0, '0);       // Reset suppresses transfers.
        step(0, 0, 0, '0,       1, 0, '0);       // Empty and idle.
        step(0, 1, 1, 16'h1234, 1, 1, 16'h1234); // Consecutive bypass beats.
        step(0, 1, 1, 16'h5678, 1, 1, 16'h5678);

        step(0, 1, 0, 16'hA123, 1, 1, 16'hA123); // Capture A on first stall.
        step(0, 1, 0, 16'hB456, 0, 1, 16'hA123); // B waits upstream.
        step(0, 1, 0, 16'hB456, 0, 1, 16'hA123);
        step(0, 1, 1, 16'hB456, 0, 1, 16'hA123); // Deliver A.
        step(0, 1, 1, 16'hB456, 1, 1, 16'hB456); // Accept and deliver B.

        step(0, 1, 0, 16'hC789, 1, 1, 16'hC789); // Capture C.
        step(0, 0, 0, '0,       0, 1, 16'hC789); // Hold C without new input.
        step(1, 0, 1, '0,       0, 0, '0);       // Flush C during reset.
        step(0, 0, 1, '0,       1, 0, '0);       // C stays flushed.
        step(0, 1, 1, 16'hDEF0, 1, 1, 16'hDEF0); // Bypass after reset.

        if (accepted != 6 || delivered != 5)
            $fatal(1, "Unexpected transfer totals: accepted=%0d delivered=%0d",
                   accepted, delivered);
        $display("PASS: skid buffer checked %0d cycles, accepted %0d beats, delivered %0d beats.",
                 cycles, accepted, delivered);
        $finish;
    end
endmodule
