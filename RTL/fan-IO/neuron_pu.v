`timescale 1ns / 1ps

//
// Module: neuron_pu_stateless_verilog
// Description: A stateless, TDM-ready LIF neuron PU in standard Verilog-2001.
//              It separates combinational logic for next-state calculation
//              from the sequential logic for output registers.
//
module neuron_pu #(
    // --- Parameters ---
    parameter VMEM_WIDTH        = 16,
    parameter DATA_WIDTH        = 8,
    parameter V_THRESH          = 120,
    parameter V_RESET           = 0,
    parameter LEAK_VAL          = 2,
    parameter REFRACTORY_PERIOD = 5
)(
    // --- Ports ---
    input  wire                          clk,
    input  wire                          rst_n,

    // --- Inputs from Memory & Controller ---
    input  wire                          i_in_valid,
    input  wire signed [VMEM_WIDTH-1:0]  i_vmem_in,
    input  wire [$clog2(REFRACTORY_PERIOD):0] i_ref_ctr_in,
    input  wire signed [DATA_WIDTH-1:0]  i_syn_current,

    // --- Outputs to be written back to Memory ---
    // always 블록에서 값을 할당받으므로 'reg' 타입으로 선언
    output reg                           o_spike,
    output reg signed [VMEM_WIDTH-1:0]   o_vmem_out,
    output reg [$clog2(REFRACTORY_PERIOD):0] o_ref_ctr_out
);

    // --- Internal Wires/Regs for Next-State Logic ---
    // 조합 논리 블록에서 계산될 '다음 상태' 값을 위한 내부 레지스터
    reg signed [VMEM_WIDTH-1:0]   next_vmem;
    reg                            next_spike;
    reg [$clog2(REFRACTORY_PERIOD):0] next_ref_ctr;

    //================================================================
    // --- Combinational Logic: Calculate Next State ---
    //================================================================
    // 이 블록은 입력이 변할 때마다 '다음 상태'를 즉시 계산합니다.
    always @(*) begin
        // 기본값 설정
        next_spike = 1'b0;

        // 불응기 상태 처리
        if (i_ref_ctr_in > 0) begin
            next_vmem    = V_RESET;
            next_ref_ctr = i_ref_ctr_in - 1;
        end
        // 일반 상태 처리
        else begin
            // Leakage
            if (i_vmem_in > V_RESET) begin
                next_vmem = i_vmem_in - LEAK_VAL;
            end else begin
                next_vmem = V_RESET;
            end
            
            // Integration (유효한 입력이 있을 때만)
            if (i_in_valid) begin
                next_vmem = next_vmem + i_syn_current;
            end
            
            next_ref_ctr = 0; // 기본값

            // Fire & Reset
            if (next_vmem >= V_THRESH) begin
                next_spike   = 1'b1;
                next_vmem    = V_RESET; // 실제 v_mem 리셋은 다음 상태에서 반영
                next_ref_ctr = REFRACTORY_PERIOD;
            end
        end
    end

    //================================================================
    // --- Sequential Logic: Register Outputs on Clock Edge ---
    //================================================================
    // 위에서 계산된 '다음 상태' 값을 클럭에 맞춰 최종 출력 레지스터에 저장합니다.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_vmem_out    <= V_RESET;
            o_spike       <= 1'b0;
            o_ref_ctr_out <= 0;
        end else begin
        
            o_spike <= next_spike;
            // 유효한 입력이 들어왔을 때만 상태를 업데이트 (Event-Driven)
            if (i_in_valid) begin
                o_vmem_out    <= next_vmem;
                o_ref_ctr_out <= next_ref_ctr;
            end
            // 유효한 입력이 없으면 출력 레지스터는 기존 값을 유지합니다.
            // (단, 스파이크 출력은 매번 0으로 리셋되도록 o_spike <= next_spike; 로 둘 수 있습니다.)
            // 여기서는 유효할 때만 업데이트하도록 구현했습니다.
        end
    end

endmodule