`timescale 1ns/1ps

module tb_round_robin_arbiter;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic [1:0] req = 2'b00;
    logic ready = 1'b0;
    logic [1:0] grant;

    int checks = 0;
    int transfers = 0;

    round_robin_arbiter dut (
        .clk   (clk),
        .rst   (rst),
        .req   (req),
        .ready (ready),
        .grant (grant)
    );

    always #5 clk = ~clk;

    task automatic step(
        input string scenario,
        input bit reset_request,
        input bit [1:0] requests,
        input bit downstream_ready,
        input bit [1:0] expected_grant
    );
        @(negedge clk);
        rst   = reset_request;
        req   = requests;
        ready = downstream_ready;

        @(posedge clk);
        if (grant !== expected_grant)
            $fatal(1, "%s: req=%b ready=%b rst=%b expected grant=%b got=%b",
                   scenario, req, ready, rst, expected_grant, grant);
        if (!$onehot0(grant) || ((grant & req) !== grant))
            $fatal(1, "%s: invalid grant %b for requests %b", scenario, grant, req);

        if (ready && (grant != 2'b00))
            transfers++;
        checks++;
    endtask

    initial begin
        step("reset suppresses a transfer", 1, 2'b11, 1, 2'b00);
        step("idle while stalled",           0, 2'b00, 0, 2'b00);
        step("idle while ready",             0, 2'b00, 1, 2'b00);

        // A higher-priority request arrives while requester 1 owns a stall.
        step("only requester 1 starts",    0, 2'b10, 0, 2'b10);
        step("requester 0 joins the stall", 0, 2'b11, 0, 2'b10);
        step("stall clears",                0, 2'b11, 1, 2'b10);

        // With both pending, the next accepted grant alternates.
        for (int i = 0; i < 8; i++) begin
            step("contended transfer to 0", 0, 2'b11, 1, 2'b01);
            step("contended transfer to 1", 0, 2'b11, 1, 2'b10);
        end

        step("only requester 0 transfers", 0, 2'b01, 1, 2'b01);
        step("idle retains priority",      0, 2'b00, 1, 2'b00);
        step("contended stall starts",     0, 2'b11, 0, 2'b10);
        step("contended stall holds",      0, 2'b11, 0, 2'b10);
        step("contended stall clears",     0, 2'b11, 1, 2'b10);
        step("priority advances",          0, 2'b11, 1, 2'b01);

        step("requester 1 stalls again",   0, 2'b11, 0, 2'b10);
        step("reset clears stalled grant", 1, 2'b11, 1, 2'b00);
        step("reset restores priority 0",  0, 2'b11, 1, 2'b01);

        if (transfers != 21)
            $fatal(1, "Expected 21 accepted transfers, got %0d", transfers);

        $display("PASS: round-robin arbiter checked %0d cycles and %0d transfers.",
                 checks, transfers);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: arbiter simulation timeout");
    end
endmodule
