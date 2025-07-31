`timescale 1ns / 1ps

module neuron_register #(
    parameter MAX_SPIKE = 128,
    parameter N_SYNAPSE = 10000
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [7:0] num_spike,                    // spike index 개수
    input wire [14*MAX_SPIKE-1:0] index_in_flat,   // flat index 리스트
    input wire [8*N_SYNAPSE-1:0] synapse_mem_flat, // flat synapse memory
    output reg [8*MAX_SPIKE-1:0] weight_flat,      // flat 가중치 리스트
    output reg [7:0] num_spike_out,
    output reg valid_out
);

    reg [13:0] index_list [0:MAX_SPIKE-1];
    reg [7:0]  weight_list [0:MAX_SPIKE-1];

    integer i;

    // flat index unpack
    always @(*) begin
        for (i = 0; i < MAX_SPIKE; i = i + 1)
            index_list[i] = index_in_flat[i*14 +: 14];
    end

    // synapse_mem_flat unpack & weight read
    always @(*) begin
        for (i = 0; i < MAX_SPIKE; i = i + 1) begin
            if (i < num_spike)
                weight_list[i] = synapse_mem_flat[ index_list[i]*8 +: 8 ];
            else
                weight_list[i] = 8'd0;
        end
    end

    // weight_list pack
    always @(*) begin
        for (i = 0; i < MAX_SPIKE; i = i + 1)
            weight_flat[i*8 +: 8] = weight_list[i];
    end

    // valid_out 관리
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_spike_out <= 8'd0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            num_spike_out <= num_spike;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule

