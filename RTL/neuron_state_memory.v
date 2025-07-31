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

    // 장점 2: 읽기/쓰기 주소 포트를 분리한 2-Port 구조
    // Read Port
    input   wire [ADDR_WIDTH-1:0]       i_read_addr,
    output  reg  [DATA_WIDTH*2+FSM_WIDTH-1:0] o_read_data,

    // Write Port
    input   wire                        i_write_en,
    input   wire [ADDR_WIDTH-1:0]       i_write_addr,
    input   wire [DATA_WIDTH*2+FSM_WIDTH-1:0] i_write_data
);

    // 장점 1: 모든 상태를 하나의 wide vector로 관리
    localparam STATE_VEC_WIDTH = DATA_WIDTH*2 + FSM_WIDTH;
    reg [STATE_VEC_WIDTH-1:0] neuron_mem [0:NEURON_COUNT-1];

    // 동기식 2-Port Read/Write 로직
    always @(posedge clk) begin
        // Write Port Logic
        // 한 사이클에 i_write_addr 주소에 데이터 쓰기
        if (i_write_en) begin
            neuron_mem[i_write_addr] <= i_write_data;
        end

        // Read Port Logic
        // 동시에 i_read_addr 주소의 데이터를 읽어서 다음 사이클에 출력
        o_read_data <= neuron_mem[i_read_addr];
    end

endmodule