`timescale 1ns / 1ps

module i_spike_if_before #(
    parameter MAX_SPIKE = 128
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [7:0] spike_num,
    input wire [14*MAX_SPIKE-1:0] spike_index_flat,  // <- flat 벡터
    output reg ready_out,
    output reg [7:0] num_spike_out,
    output reg [14*MAX_SPIKE-1:0] index_out_flat     // <- flat 벡터
);
    // 내부 unpacked array로 변환 (예시)
    reg [13:0] spike_index [0:MAX_SPIKE-1];
    reg [13:0] index_out [0:MAX_SPIKE-1];

    integer i;
    always @(*) begin
        for (i = 0; i < MAX_SPIKE; i = i + 1) begin
            spike_index[i] = spike_index_flat[i*14 +: 14];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_out <= 1'b1;
            num_spike_out <= 8'd0;
            for (i = 0; i < MAX_SPIKE; i = i + 1)
                index_out[i] <= 14'd0;
        end else if (valid_in && ready_out) begin
            num_spike_out <= spike_num;
            for (i = 0; i < spike_num; i = i + 1)
                index_out[i] <= spike_index[i];
            for (i = spike_num; i < MAX_SPIKE; i = i + 1)
                index_out[i] <= 14'd0;
            ready_out <= 1'b0; // fetch 끝나면 다시 1로
        end
    end

    // 내부 array -> flat 벡터로 packing
    always @(*) begin
        for (i = 0; i < MAX_SPIKE; i = i + 1)
            index_out_flat[i*14 +: 14] = index_out[i];
    end
endmodule
