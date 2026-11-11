`timescale 1ns/1ps

module tb_sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 8
);
    localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam int CROSS_BINS = (DEPTH + 1) * 4;

    logic clk = 1'b0;
    logic rst;
    logic wr_en;
    logic rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic full;
    logic empty;
    logic [COUNT_WIDTH-1:0] count;

    // Independent reference queue and expected output register.
    logic [DATA_WIDTH-1:0] model_queue[$];
    logic [DATA_WIDTH-1:0] expected_rd_data;

    int checks = 0;

    // Explicit functional coverage counters.
    int occupancy_hits [0:DEPTH] = '{default:0};
    int request_hits [0:3] = '{default:0};
    int simultaneous_empty_hits = 0;
    int simultaneous_full_hits = 0;
    int simultaneous_middle_hits = 0;
    int reset_nonempty_hits = 0;

    // Cross coverage: pre-transaction occupancy x {write, read}.
    int occupancy_request_hits [0:DEPTH][0:3] =
        '{default:'{default:0}};

    int cross_bins_hit = 0;

    sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
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
        input logic [DATA_WIDTH-1:0] data
    );
        bit accept_write;
        bit accept_read;
        int expected_count;
        int occupancy_before;
        bit [1:0] requests;

        // Drive inputs away from the DUT's rising clock edge.
        @(negedge clk);
        rst     = reset_request;
        wr_en   = write_request;
        rd_en   = read_request;
        wr_data = data;

        // Acceptance uses occupancy before this transaction.
        occupancy_before = model_queue.size();
        requests = {write_request, read_request};
        accept_write = write_request && (occupancy_before < DEPTH);
        accept_read  = read_request && (occupancy_before > 0);

        @(posedge clk);

        // Sample coverage before updating the reference queue.
        if (reset_request) begin
            if (occupancy_before > 0)
                reset_nonempty_hits++;
        end else begin
            occupancy_hits[occupancy_before]++;
            request_hits[requests]++;
            occupancy_request_hits[occupancy_before][requests]++;

            if (write_request && read_request) begin
                if (occupancy_before == 0)
                    simultaneous_empty_hits++;
                else if (occupancy_before == DEPTH)
                    simultaneous_full_hits++;
                else
                    simultaneous_middle_hits++;
            end
        end

        if (reset_request) begin
            model_queue.delete();
            expected_rd_data = '0;
        end else begin
            // Pop first: simultaneous read returns old FIFO data.
            if (accept_read)
                expected_rd_data = model_queue.pop_front();

            if (accept_write)
                model_queue.push_back(data);
        end

        // Allow nonblocking assignments to settle.
        #1;

        expected_count = model_queue.size();

        if (count !== COUNT_WIDTH'(expected_count))
            $fatal(1, "Count mismatch: expected %0d, got %0d",
                   expected_count, count);

        if (empty !== (expected_count == 0))
            $fatal(1, "Empty flag mismatch");

        if (full !== (expected_count == DEPTH))
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
        wr_data          = '0;
        expected_rd_data = '0;

        $display("TEST: reset and empty read");
        step(1, 0, 0, '0);
        step(0, 0, 1, '0);

        $display("TEST: single write/read and output hold");
        step(0, 1, 0, '1);
        step(0, 0, 1, '0);
        step(0, 0, 0, '0);

        $display("TEST: fill, reject overflow, and drain");
        for (int i = 0; i < DEPTH; i++)
            step(0, 1, 0, DATA_WIDTH'(32'h10 + i));

        step(0, 1, 0, DATA_WIDTH'(8'hFF));

        for (int i = 0; i < DEPTH; i++)
            step(0, 0, 1, '0);

        step(0, 0, 1, '0);

        $display("TEST: simultaneous requests while empty");
        step(0, 1, 1, DATA_WIDTH'(8'hB1));
        step(0, 0, 1, '0);

        $display("TEST: simultaneous requests while full");
        for (int i = 0; i < DEPTH; i++)
            step(0, 1, 0, DATA_WIDTH'(32'h20 + i));

        // Read accepted; write rejected because FIFO starts full.
        step(0, 1, 1, DATA_WIDTH'(8'hEE));

        for (int i = 0; i < DEPTH - 1; i++)
            step(0, 0, 1, '0);

        if (DEPTH > 1) begin
            $display("TEST: simultaneous requests while partially filled");
            step(0, 1, 0, DATA_WIDTH'(8'h31));
            step(0, 1, 1, DATA_WIDTH'(8'h33));
            step(0, 0, 1, '0);
        end

        $display("TEST: repeated pointer wraparound");
        for (int round_idx = 0; round_idx < 3; round_idx++) begin
            for (int i = 0; i < DEPTH; i++)
                step(0, 1, 0, DATA_WIDTH'(round_idx * DEPTH + i));

            for (int i = 0; i < DEPTH; i++)
                step(0, 0, 1, '0);
        end

        $display("TEST: reset with queued data and requests asserted");
        step(0, 1, 0, DATA_WIDTH'(8'hD1));
        step(0, 1, 0, DATA_WIDTH'(8'hD2));
        step(1, 1, 1, DATA_WIDTH'(8'hFF));
        step(0, 0, 1, '0);

        $display("TEST: operation after reset");
        step(0, 1, 0, DATA_WIDTH'(8'h5A));
        step(0, 0, 1, '0);

        $display("TEST: deterministic occupancy/request sweep");

        for (int occ = 0; occ <= DEPTH; occ++) begin
            for (int req = 0; req < 4; req++) begin
                // Start each case from a known empty FIFO.
                step(1, 0, 0, '0);

                // Establish the required pre-transaction occupancy.
                for (int entry_idx = 0; entry_idx < occ; entry_idx++)
                    step(0, 1, 0, DATA_WIDTH'(32'h40 + entry_idx));

                // req[1] = write request; req[0] = read request.
                step(0, req[1], req[0], DATA_WIDTH'(8'hA5));
            end
        end

        // Restore an empty FIFO before randomized traffic.
        step(1, 0, 0, '0);

        $display("TEST: 500 randomized transaction cycles");
        for (int i = 0; i < 500; i++) begin
            step(
                ($urandom_range(49, 0) == 0),
                1'($urandom_range(1, 0)),
                1'($urandom_range(1, 0)),
                DATA_WIDTH'($urandom)
            );
        end

        $display("TEST: drain remaining reference data");
        while (model_queue.size() > 0)
            step(0, 0, 1, '0);

        step(0, 0, 1, '0);

        // Let the final cycle's assertion process finish.
        #1;

        $display("COVERAGE: pre-transaction occupancy");
        for (int i = 0; i <= DEPTH; i++) begin
            $display("  occupancy %0d: %0d hits",
                     i, occupancy_hits[i]);

            if (occupancy_hits[i] == 0)
                $fatal(1, "COVERAGE GAP: occupancy %0d", i);
        end

        $display("COVERAGE: requests {write, read}");
        for (int i = 0; i < 4; i++) begin
            $display("  request combination %02b: %0d hits",
                     i[1:0], request_hits[i]);

            if (request_hits[i] == 0)
                $fatal(1, "COVERAGE GAP: request combination %02b",
                       i[1:0]);
        end

        $display("COVERAGE: simultaneous empty=%0d full=%0d middle=%0d",
                 simultaneous_empty_hits,
                 simultaneous_full_hits,
                 simultaneous_middle_hits);

        $display("COVERAGE: reset while nonempty=%0d",
                 reset_nonempty_hits);

        if ((simultaneous_empty_hits == 0) ||
            (simultaneous_full_hits == 0) ||
            ((DEPTH > 1) && (simultaneous_middle_hits == 0)) ||
            (reset_nonempty_hits == 0))
            $fatal(1, "COVERAGE GAP: required corner case missing");

        // Report and enforce all occupancy/request bins.
        $display("COVERAGE: occupancy x requests {write, read}");
        cross_bins_hit = 0;

        for (int occ = 0; occ <= DEPTH; occ++) begin
            for (int req = 0; req < 4; req++) begin
                $display("  occupancy=%0d requests=%02b hits=%0d",
                         occ, req[1:0],
                         occupancy_request_hits[occ][req]);

                if (occupancy_request_hits[occ][req] > 0)
                    cross_bins_hit++;
            end
        end

        $display("COVERAGE: cross bins hit=%0d/%0d",
                 cross_bins_hit, CROSS_BINS);

        if (cross_bins_hit != CROSS_BINS)
            $fatal(1, "COVERAGE GAP: only %0d/%0d cross bins hit",
                   cross_bins_hit, CROSS_BINS);

        $display("PASS: synchronous FIFO passed %0d checked cycles.",
                 checks);
        $finish;
    end

    // Stop a stalled test instead of running forever.
    initial begin
        #(10 * (600 + 4 * (DEPTH + 1) * (DEPTH + 2)));
        $fatal(1, "FAIL: simulation timeout");
    end

    // Sample before the DUT update, then check after it settles.
    always @(posedge clk) begin : fifo_assertions
        logic sampled_reset;
        logic accepted_write;
        logic accepted_read;
        logic [PTR_WIDTH-1:0] old_wr_ptr;
        logic [PTR_WIDTH-1:0] old_rd_ptr;
        logic [PTR_WIDTH-1:0] expected_wr_ptr;
        logic [PTR_WIDTH-1:0] expected_rd_ptr;
        int expected_occupancy;

        sampled_reset = rst;
        old_wr_ptr = dut.wr_ptr;
        old_rd_ptr = dut.rd_ptr;

        accepted_write = wr_en && (count < COUNT_WIDTH'(DEPTH));
        accepted_read  = rd_en && (count != '0);

        expected_occupancy = int'(count);
        expected_wr_ptr = old_wr_ptr;
        expected_rd_ptr = old_rd_ptr;

        if (sampled_reset) begin
            expected_occupancy = 0;
            expected_wr_ptr = '0;
            expected_rd_ptr = '0;
        end else begin
            if (accepted_write) begin
                expected_occupancy++;
                expected_wr_ptr = PTR_WIDTH'((int'(old_wr_ptr) + 1) % DEPTH);
            end

            if (accepted_read) begin
                expected_occupancy--;
                expected_rd_ptr = PTR_WIDTH'((int'(old_rd_ptr) + 1) % DEPTH);
            end
        end

        #1;

        a_count_known_and_bounded:
            assert (!$isunknown(count) && (int'(count) <= DEPTH))
            else $fatal(1, "ASSERT: occupancy unknown or above depth");

        a_count_transition:
            assert (count === COUNT_WIDTH'(expected_occupancy))
            else $fatal(1, "ASSERT: incorrect occupancy update");

        a_write_pointer:
            assert (dut.wr_ptr === expected_wr_ptr)
            else $fatal(1, "ASSERT: incorrect write pointer update");

        a_read_pointer:
            assert (dut.rd_ptr === expected_rd_ptr)
            else $fatal(1, "ASSERT: incorrect read pointer update");

        if (sampled_reset) begin
            a_reset_output:
                assert (rd_data === '0)
                else $fatal(1, "ASSERT: reset did not clear read output");
        end
    end

endmodule

module tb_sync_fifo_depth1;
    tb_sync_fifo #(.DATA_WIDTH(1), .DEPTH(1)) test_fifo();
endmodule

module tb_sync_fifo_depth5;
    tb_sync_fifo #(.DATA_WIDTH(16), .DEPTH(5)) test_fifo();
endmodule
