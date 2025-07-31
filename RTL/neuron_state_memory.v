`timescale 1ns / 1ps

// Module: neuron_state_memory_hybrid
// Function: A high-performance, flexible, 2-Port Neuron State Memory.
//           Combines a packed vector data structure with a 2-port interface.
module neuron_state_memory #(
    parameter NEURON_COUNT = 10000,
    parameter ADDR_WIDTH   = 14,
    parameter DATA_WIDTH   = 8,
    parameter FSM_WIDTH    = 2
)(
    input   wire                        clk,
    input   wire                        rst_n,

    // ���� 2: �б�/���� �ּ� ��Ʈ�� �и��� 2-Port ����
    // Read Port
    input   wire [ADDR_WIDTH-1:0]       i_read_addr,
    output  reg  [DATA_WIDTH*2+FSM_WIDTH-1:0] o_read_data,

    // Write Port
    input   wire                        i_write_en,
    input   wire [ADDR_WIDTH-1:0]       i_write_addr,
    input   wire [DATA_WIDTH*2+FSM_WIDTH-1:0] i_write_data
);

    // ���� 1: ��� ���¸� �ϳ��� wide vector�� ����
    localparam STATE_VEC_WIDTH = DATA_WIDTH*2 + FSM_WIDTH;
    reg [STATE_VEC_WIDTH-1:0] neuron_mem [0:NEURON_COUNT-1];

    // ����� 2-Port Read/Write ����
    always @(posedge clk) begin
        // Write Port Logic
        // �� ����Ŭ�� i_write_addr �ּҿ� ������ ����
        if (i_write_en) begin
            neuron_mem[i_write_addr] <= i_write_data;
        end

        // Read Port Logic
        // ���ÿ� i_read_addr �ּ��� �����͸� �о ���� ����Ŭ�� ���
        o_read_data <= neuron_mem[i_read_addr];
    end

endmodule