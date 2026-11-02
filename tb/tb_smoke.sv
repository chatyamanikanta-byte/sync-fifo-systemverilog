`timescale 1ns/1ps

module tb_smoke;

    logic clk;
    logic rst;
    logic [3:0] count;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (rst)
            count <= 4'd0;
        else
            count <= count + 4'd1;
    end

    initial begin
        rst = 1'b1;

        // Hold reset across two rising clock edges.
        repeat (2) @(negedge clk);

        if (count !== 4'd0)
            $fatal(1, "FAIL: reset did not clear the counter");

        rst = 1'b0;

        // Check after each rising-edge update has settled.
        for (int expected = 1; expected <= 5; expected++) begin
            @(negedge clk);
            if (count !== expected[3:0])
                $fatal(1, "FAIL: expected %0d, received %0d",
                       expected, count);
        end

        $display("PASS: clock, reset, and counter checks passed.");
        $finish;
    end

endmodule
