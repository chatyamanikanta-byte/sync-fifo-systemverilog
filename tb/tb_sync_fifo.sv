`timescale 1ns/1ps

module tb_sync_fifo;

    logic clk = 1'b0;
    logic rst;
    logic wr_en;
    logic rd_en;
    logic [7:0] wr_data;
    logic [7:0] rd_data;
    logic full;
    logic empty;
    logic [3:0] count;

    // Independent reference queue and expected output register.
    logic [7:0] model_queue[$];
    logic [7:0] expected_rd_data;

    int checks = 0;

    sync_fifo dut (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .full    (full),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .empty   (empty),
        .count   (count)
    );

    always #5 clk = ~clk;

    task automatic step(
        input bit reset_request,
        input bit write_request,
        input bit read_request,
        input logic [7:0] data
    );
        bit accept_write;
        bit accept_read;
        int expected_count;

        // Drive inputs away from the DUT's rising clock edge.
        @(negedge clk);
        rst     = reset_request;
        wr_en   = write_request;
        rd_en   = read_request;
        wr_data = data;

        // Determine acceptance using the reference model's
        // occupancy BEFORE this transaction.
        accept_write = write_request &&
                       (model_queue.size() < 8);
        accept_read  = read_request &&
                       (model_queue.size() > 0);

        @(posedge clk);

        if (reset_request) begin
            model_queue.delete();
            expected_rd_data = 8'd0;
        end else begin
            // Pop first: a simultaneous read returns old FIFO data.
            if (accept_read)
                expected_rd_data = model_queue.pop_front();

            if (accept_write)
                model_queue.push_back(data);
        end

        // Allow the DUT's nonblocking assignments to settle.
        #1;

        expected_count = model_queue.size();

        if (count !== expected_count[3:0])
            $fatal(1, "Count mismatch: expected %0d, got %0d",
                   expected_count, count);

        if (empty !== (expected_count == 0))
            $fatal(1, "Empty flag mismatch");

        if (full !== (expected_count == 8))
            $fatal(1, "Full flag mismatch");

        if (rd_data !== expected_rd_data)
            $fatal(1, "Read mismatch: expected %02h, got %02h",
                   expected_rd_data, rd_data);

        checks++;
    endtask

    initial begin
        rst              = 1'b1;
        wr_en            = 1'b0;
        rd_en            = 1'b0;
        wr_data          = 8'd0;
        expected_rd_data = 8'd0;

        $display("TEST: reset and empty read");
        step(1, 0, 0, 8'h00);
        step(0, 0, 1, 8'h00);

        $display("TEST: single write/read and output hold");
        step(0, 1, 0, 8'hA5);
        step(0, 0, 1, 8'h00);
        step(0, 0, 0, 8'h00);

        $display("TEST: fill, reject overflow, and drain");
        for (int i = 0; i < 8; i++)
            step(0, 1, 0, 8'h10 + i);

        step(0, 1, 0, 8'hFF);

        for (int i = 0; i < 8; i++)
            step(0, 0, 1, 8'h00);

        step(0, 0, 1, 8'h00);

        $display("TEST: simultaneous requests while empty");
        step(0, 1, 1, 8'hB1);
        step(0, 0, 1, 8'h00);

        $display("TEST: simultaneous requests while full");
        for (int i = 0; i < 8; i++)
            step(0, 1, 0, 8'h20 + i);

        // Read accepted; write rejected because FIFO starts full.
        step(0, 1, 1, 8'hEE);

        for (int i = 0; i < 7; i++)
            step(0, 0, 1, 8'h00);

        $display("TEST: simultaneous requests while partially filled");
        step(0, 1, 0, 8'h31);
        step(0, 1, 0, 8'h32);
        step(0, 1, 1, 8'h33);
        step(0, 0, 1, 8'h00);
        step(0, 0, 1, 8'h00);

        $display("TEST: repeated pointer wraparound");
        for (int round_idx = 0; round_idx < 3; round_idx++) begin
            for (int i = 0; i < 8; i++)
                step(0, 1, 0, round_idx * 8 + i);

            for (int i = 0; i < 8; i++)
                step(0, 0, 1, 8'h00);
        end

        $display("TEST: reset with queued data and requests asserted");
        step(0, 1, 0, 8'hD1);
        step(0, 1, 0, 8'hD2);
        step(1, 1, 1, 8'hFF);
        step(0, 0, 1, 8'h00);

             $display("TEST: operation after reset");
        step(0, 1, 0, 8'h5A);
        step(0, 0, 1, 8'h00);

        $display("TEST: 500 randomized transaction cycles");

        for (int i = 0; i < 500; i++) begin
            step(
                ($urandom_range(0, 49) == 0),
                $urandom_range(0, 1),
                $urandom_range(0, 1),
                $urandom_range(0, 255)
            );
        end

        $display("TEST: drain remaining reference data");

        while (model_queue.size() > 0)
            step(0, 0, 1, 8'h00);

        step(0, 0, 1, 8'h00);

        $display("PASS: synchronous FIFO passed %0d checked cycles.",
                 checks);
        $finish;
    end

    // Stop a stalled test instead of running forever.
    initial begin
        #10000;
        $fatal(1, "FAIL: simulation timeout");
    end
    // Immediate assertions: sample before the edge update,
    // then check after nonblocking assignments have settled.
    always @(posedge clk) begin : fifo_assertions
        logic sampled_reset;
        logic accepted_write;
        logic accepted_read;
        logic [2:0] old_wr_ptr;
        logic [2:0] old_rd_ptr;
        logic [2:0] expected_wr_ptr;
        logic [2:0] expected_rd_ptr;
        int expected_occupancy;

        sampled_reset = rst;
        old_wr_ptr = dut.wr_ptr;
        old_rd_ptr = dut.rd_ptr;

        // Derive acceptance from the specified boundary rules.
        accepted_write = wr_en && (count < 4'd8);
        accepted_read  = rd_en && (count > 4'd0);

        expected_occupancy = int'(count);
        expected_wr_ptr = old_wr_ptr;
        expected_rd_ptr = old_rd_ptr;

        if (sampled_reset) begin
            expected_occupancy = 0;
            expected_wr_ptr = 3'd0;
            expected_rd_ptr = 3'd0;
        end else begin
            if (accepted_write) begin
                expected_occupancy++;
                expected_wr_ptr = old_wr_ptr + 3'd1;
            end

            if (accepted_read) begin
                expected_occupancy--;
                expected_rd_ptr = old_rd_ptr + 3'd1;
            end
        end

        #1;

        a_count_known_and_bounded:
            assert (!$isunknown(count) && (count <= 4'd8))
            else $fatal(1, "ASSERT: occupancy unknown or above depth");

        a_count_transition:
            assert (count === expected_occupancy[3:0])
            else $fatal(1, "ASSERT: incorrect occupancy update");

        a_write_pointer:
            assert (dut.wr_ptr === expected_wr_ptr)
            else $fatal(1, "ASSERT: incorrect write pointer update");

        a_read_pointer:
            assert (dut.rd_ptr === expected_rd_ptr)
            else $fatal(1, "ASSERT: incorrect read pointer update");

        if (sampled_reset) begin
            a_reset_output:
                assert (rd_data === 8'd0)
                else $fatal(1, "ASSERT: reset did not clear read output");
        end
    end
endmodule
