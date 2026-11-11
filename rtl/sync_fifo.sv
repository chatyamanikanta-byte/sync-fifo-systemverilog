`timescale 1ns/1ps

module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 8,
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1)
) (
    input  logic       clk,
    input  logic       rst,

    input  logic       wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic       full,

    input  logic       rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic       empty,

    output logic [COUNT_WIDTH-1:0] count
);

    localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam logic [PTR_WIDTH-1:0] LAST_ADDR = PTR_WIDTH'(DEPTH - 1);
    localparam logic [COUNT_WIDTH-1:0] FULL_COUNT = COUNT_WIDTH'(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr;
    logic [PTR_WIDTH-1:0] rd_ptr;

    logic write_accept;
    logic read_accept;

    assign full  = (count == FULL_COUNT);
    assign empty = (count == '0);

    assign write_accept = wr_en && !full;
    assign read_accept  = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr  <= '0;
            rd_ptr  <= '0;
            count   <= '0;
            rd_data <= '0;
        end else begin

            if (write_accept) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr     <= (wr_ptr == LAST_ADDR) ? '0 : wr_ptr + 1'b1;
            end

            if (read_accept) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= (rd_ptr == LAST_ADDR) ? '0 : rd_ptr + 1'b1;
            end

            case ({write_accept, read_accept})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase

        end
    end

endmodule
