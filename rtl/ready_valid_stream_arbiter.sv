`timescale 1ns/1ps

module ready_valid_stream_arbiter #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic [1:0]            in_valid,
    output logic [1:0]            in_ready,
    input  logic [DATA_WIDTH-1:0] in_data0,
    input  logic [DATA_WIDTH-1:0] in_data1,
    output logic                  out_valid,
    input  logic                  out_ready,
    output logic [DATA_WIDTH-1:0] out_data
);

    logic [1:0] grant;
    logic skid_ready;
    logic [DATA_WIDTH-1:0] selected_data;

    assign in_ready = grant & {2{skid_ready}};
    assign selected_data = grant[1] ? in_data1 : in_data0;

    round_robin_arbiter arbiter (
        .clk(clk),
        .rst(rst),
        .req(in_valid),
        .ready(skid_ready),
        .grant(grant)
    );

    ready_valid_skid_buffer #(.DATA_WIDTH(DATA_WIDTH)) skid_buffer (
        .clk(clk),
        .rst(rst),
        .in_valid(|grant),
        .in_ready(skid_ready),
        .in_data(selected_data),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_data(out_data)
    );

endmodule
