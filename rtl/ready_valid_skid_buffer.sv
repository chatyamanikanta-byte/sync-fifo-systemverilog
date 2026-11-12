`timescale 1ns/1ps

module ready_valid_skid_buffer #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  in_valid,
    output logic                  in_ready,
    input  logic [DATA_WIDTH-1:0] in_data,
    output logic                  out_valid,
    input  logic                  out_ready,
    output logic [DATA_WIDTH-1:0] out_data
);

    logic full;
    logic [DATA_WIDTH-1:0] saved_data;

    assign in_ready = !rst && !full;
    assign out_valid = !rst && (full || in_valid);
    assign out_data = full ? saved_data : in_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            full <= 1'b0;
        end else if (full) begin
            if (out_ready)
                full <= 1'b0;
        end else if (in_valid && !out_ready) begin
            // Upstream transferred a beat that downstream could not accept.
            saved_data <= in_data;
            full <= 1'b1;
        end
    end

endmodule
