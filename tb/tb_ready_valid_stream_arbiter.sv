`timescale 1ns/1ps

module tb_ready_valid_stream_arbiter;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic [1:0] in_valid = '0;
    logic [1:0] in_ready;
    logic [7:0] in_data0 = '0;
    logic [7:0] in_data1 = '0;
    logic out_valid, out_ready = 1'b0;
    logic [7:0] out_data;
    int cycles = 0;
    int accepted = 0;
    int delivered = 0;

    always #5 clk = !clk;

    ready_valid_stream_arbiter dut (.*);

    task automatic step(
        input logic reset, sink_ready,
        input logic [1:0] valid,
        input logic [7:0] data0, data1,
        input logic [1:0] expected_accept,
        input logic expected_valid,
        input logic [7:0] expected_data
    );
        logic [1:0] source_accept;
        @(negedge clk);
        rst = reset;
        out_ready = sink_ready;
        in_valid = valid;
        in_data0 = data0;
        in_data1 = data1;

        @(posedge clk);
        cycles++;
        source_accept = in_valid & in_ready;
        if (source_accept !== expected_accept ||
            out_valid !== expected_valid ||
            (expected_valid && out_data !== expected_data))
            $fatal(1, "Cycle %0d expected accept/valid/data %b/%b/%h, got %b/%b/%h",
                   cycles, expected_accept, expected_valid, expected_data,
                   source_accept, out_valid, out_data);

        if (|source_accept)
            accepted++;
        if (out_valid && out_ready)
            delivered++;
    endtask

    initial begin
        step(1, 1, 2'b11, 8'hA0, 8'hB0, 2'b00, 0, '0);
        step(0, 1, 2'b11, 8'hA0, 8'hB0, 2'b01, 1, 8'hA0); // First tie goes to 0.
        step(0, 1, 2'b11, 8'hA1, 8'hB0, 2'b10, 1, 8'hB0); // Then 1.
        step(0, 0, 2'b11, 8'hA1, 8'hB1, 2'b01, 1, 8'hA1); // Capture A1.
        step(0, 0, 2'b11, 8'hA2, 8'hB1, 2'b00, 1, 8'hA1);
        step(0, 1, 2'b11, 8'hA2, 8'hB1, 2'b00, 1, 8'hA1); // Drain only.
        step(0, 1, 2'b11, 8'hA2, 8'hB1, 2'b10, 1, 8'hB1); // Resume with 1.
        step(0, 1, 2'b01, 8'hA2, '0,    2'b01, 1, 8'hA2);

        step(0, 0, 2'b10, '0,    8'hB2, 2'b10, 1, 8'hB2); // Capture B2.
        step(0, 0, 2'b10, '0,    8'hB3, 2'b00, 1, 8'hB2); // Lock source 1.
        step(0, 1, 2'b11, 8'hA3, 8'hB3, 2'b00, 1, 8'hB2); // Late source 0.
        step(0, 1, 2'b11, 8'hA3, 8'hB3, 2'b10, 1, 8'hB3); // Keep lock.
        step(0, 1, 2'b01, 8'hA3, '0,    2'b01, 1, 8'hA3);
        step(0, 1, 2'b00, '0,    '0,    2'b00, 0, '0);

        if (accepted != 8 || delivered != 8)
            $fatal(1, "Expected 8 beats at each interface, got %0d in and %0d out",
                   accepted, delivered);
        $display("PASS: stream arbiter checked %0d cycles and delivered %0d beats.",
                 cycles, delivered);
        $finish;
    end
endmodule
