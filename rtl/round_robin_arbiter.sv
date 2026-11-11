`timescale 1ns/1ps

module round_robin_arbiter (
    input  logic       clk,
    input  logic       rst,
    input  logic [1:0] req,
    input  logic       ready,
    output logic [1:0] grant
);

    logic prefer_req1;
    logic [1:0] stalled_grant;

    // Requesters hold valid and payload until their transfer is accepted.
    // A selected requester keeps the grant until ready rises.
    always_comb begin
        grant = 2'b00;
        if (!rst) begin
            if (stalled_grant != 2'b00)
                grant = stalled_grant;
            else begin
                case (req)
                    2'b01: grant = 2'b01;
                    2'b10: grant = 2'b10;
                    2'b11: grant = prefer_req1 ? 2'b10 : 2'b01;
                    default: grant = 2'b00;
                endcase
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            prefer_req1   <= 1'b0;
            stalled_grant <= 2'b00;
        end else if (grant != 2'b00) begin
            if (ready) begin
                prefer_req1   <= grant[0];
                stalled_grant <= 2'b00;
            end else begin
                stalled_grant <= grant;
            end
        end
    end

endmodule
