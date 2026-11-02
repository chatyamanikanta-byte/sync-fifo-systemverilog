`timescale 1ns/1ps

module sync_fifo (
    input  logic       clk,
    input  logic       rst,

    input  logic       wr_en,
    input  logic [7:0] wr_data,
    output logic       full,

    input  logic       rd_en,
    output logic [7:0] rd_data,
    output logic       empty,

    output logic [3:0] count
);

    logic [7:0] mem [0:7];
    logic [2:0] wr_ptr;
    logic [2:0] rd_ptr;

    logic write_accept;
    logic read_accept;

    assign full  = (count == 4'd8);
    assign empty = (count == 4'd0);

    assign write_accept = wr_en && !full;
    assign read_accept  = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr  <= 3'd0;
            rd_ptr  <= 3'd0;
            count   <= 4'd0;
            rd_data <= 8'd0;
        end else begin

            if (write_accept) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr     <= wr_ptr + 3'd2;
            end

            if (read_accept) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 3'd1;
            end

            case ({write_accept, read_accept})
                2'b10:   count <= count + 4'd1;
                2'b01:   count <= count - 4'd1;
                default: count <= count;
            endcase

        end
    end

endmodule
