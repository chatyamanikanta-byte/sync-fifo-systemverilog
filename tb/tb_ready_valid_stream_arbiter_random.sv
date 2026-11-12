`timescale 1ns/1ps

module tb_ready_valid_stream_arbiter_random;
    localparam int RANDOM_CYCLES = 2000;
    localparam int DRAIN_CYCLES = 8;
    localparam int TOTAL_CYCLES = RANDOM_CYCLES + DRAIN_CYCLES;

    logic clk = 0;
    logic rst = 1;
    logic [1:0] in_valid = '0;
    logic [1:0] in_ready;
    logic [31:0] in_data0 = '0;
    logic [31:0] in_data1 = '0;
    logic out_valid;
    logic out_ready = 0;
    logic [31:0] out_data;

    logic [31:0] expected [0:TOTAL_CYCLES-1];
    int accepted = 0;
    int delivered = 0;
    int accepted0 = 0;
    int accepted1 = 0;
    int contention_cycles = 0;
    int stall_cycles = 0;
    bit stalled = 0;
    logic [31:0] stalled_data;
    logic [1:0] source_transfer;
    int unsigned seed;
    int unsigned random_state;
    bit sink_ready;
    bit offer0;
    bit offer1;

    always #5 clk = !clk;

    ready_valid_stream_arbiter #(.DATA_WIDTH(32)) dut (.*);

    // The same nonzero seed generates the same stimulus in both simulators.
    function automatic int unsigned next_random(input int unsigned state);
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
    endfunction

    initial begin
        if (!$value$plusargs("seed=%d", seed))
            seed = 1;
        if (seed == 0)
            $fatal(1, "Seed must be nonzero");
        random_state = seed;

        for (int cycle = 0; cycle < TOTAL_CYCLES; cycle++) begin
            @(negedge clk);
            rst = 0;
            random_state = next_random(random_state);
            offer0 = random_state[0];
            offer1 = random_state[1];
            sink_ready = random_state[2] || random_state[3];
            out_ready = cycle >= RANDOM_CYCLES || sink_ready;

            // Keep a pending source beat unchanged until its handshake.
            if (!in_valid[0] && cycle < RANDOM_CYCLES && offer0) begin
                in_valid[0] = 1;
                in_data0 = 32'hA000_0000 | cycle;
            end
            if (!in_valid[1] && cycle < RANDOM_CYCLES && offer1) begin
                in_valid[1] = 1;
                in_data1 = 32'hB000_0000 | cycle;
            end

            @(posedge clk);
            source_transfer = in_valid & in_ready;
            if (source_transfer === 2'b11 || (^source_transfer) === 1'bx ||
                out_valid === 1'bx)
                $fatal(1, "Seed %0d cycle %0d: invalid handshake", seed, cycle);
            if (stalled && (out_valid !== 1'b1 || out_data !== stalled_data))
                $fatal(1, "Seed %0d cycle %0d: output changed under stall", seed, cycle);

            if (in_valid == 2'b11)
                contention_cycles++;
            stalled = out_valid && !out_ready;
            if (stalled) begin
                stalled_data = out_data;
                stall_cycles++;
            end

            // Enqueue first so an empty buffer can bypass a beat on this edge.
            if (|source_transfer) begin
                if (accepted >= TOTAL_CYCLES)
                    $fatal(1, "Seed %0d: scoreboard capacity exceeded", seed);
                expected[accepted] = source_transfer[0] ? in_data0 : in_data1;
                accepted++;
                if (source_transfer[0])
                    accepted0++;
                else
                    accepted1++;
            end
            if (out_valid && out_ready) begin
                if (delivered >= accepted)
                    $fatal(1, "Seed %0d cycle %0d: unexpected output %h",
                           seed, cycle, out_data);
                if (out_data !== expected[delivered])
                    $fatal(1, "Seed %0d cycle %0d: expected %h, got %h",
                           seed, cycle, expected[delivered], out_data);
                delivered++;
            end
            if (accepted - delivered > 1)
                $fatal(1, "Seed %0d cycle %0d: more than one beat buffered", seed, cycle);

            #1;
            in_valid &= ~source_transfer;
        end

        if (in_valid != '0 || accepted != delivered || out_valid !== 1'b0)
            $fatal(1, "Seed %0d: drain incomplete", seed);
        if (accepted0 == 0 || accepted1 == 0 || contention_cycles == 0 || stall_cycles == 0)
            $fatal(1, "Seed %0d: required traffic or stall coverage missing", seed);

        $display("PASS: seed %0d, %0d cycles, %0d delivered (%0d source 0, %0d source 1), %0d contention, %0d stall",
                 seed, TOTAL_CYCLES, delivered, accepted0,
                 accepted1, contention_cycles, stall_cycles);
        $finish;
    end
endmodule
