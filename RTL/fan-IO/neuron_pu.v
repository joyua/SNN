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
    // always ��Ͽ��� ���� �Ҵ�����Ƿ� 'reg' Ÿ������ ����
    output reg                           o_spike,
    output reg signed [VMEM_WIDTH-1:0]   o_vmem_out,
    output reg [$clog2(REFRACTORY_PERIOD):0] o_ref_ctr_out
);

    // --- Internal Wires/Regs for Next-State Logic ---
    // ���� �� ��Ͽ��� ���� '���� ����' ���� ���� ���� ��������
    reg signed [VMEM_WIDTH-1:0]   next_vmem;
    reg                            next_spike;
    reg [$clog2(REFRACTORY_PERIOD):0] next_ref_ctr;

    //================================================================
    // --- Combinational Logic: Calculate Next State ---
    //================================================================
    // �� ����� �Է��� ���� ������ '���� ����'�� ��� ����մϴ�.
    always @(*) begin
        // �⺻�� ����
        next_spike = 1'b0;

        // ������ ���� ó��
        if (i_ref_ctr_in > 0) begin
            next_vmem    = V_RESET;
            next_ref_ctr = i_ref_ctr_in - 1;
        end
        // �Ϲ� ���� ó��
        else begin
            // Leakage
            if (i_vmem_in > V_RESET) begin
                next_vmem = i_vmem_in - LEAK_VAL;
            end else begin
                next_vmem = V_RESET;
            end
            
            // Integration (��ȿ�� �Է��� ���� ����)
            if (i_in_valid) begin
                next_vmem = next_vmem + i_syn_current;
            end
            
            next_ref_ctr = 0; // �⺻��

            // Fire & Reset
            if (next_vmem >= V_THRESH) begin
                next_spike   = 1'b1;
                next_vmem    = V_RESET; // ���� v_mem ������ ���� ���¿��� �ݿ�
                next_ref_ctr = REFRACTORY_PERIOD;
            end
        end
    end

    //================================================================
    // --- Sequential Logic: Register Outputs on Clock Edge ---
    //================================================================
    // ������ ���� '���� ����' ���� Ŭ���� ���� ���� ��� �������Ϳ� �����մϴ�.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_vmem_out    <= V_RESET;
            o_spike       <= 1'b0;
            o_ref_ctr_out <= 0;
        end else begin
        
            o_spike <= next_spike;
            // ��ȿ�� �Է��� ������ ���� ���¸� ������Ʈ (Event-Driven)
            if (i_in_valid) begin
                o_vmem_out    <= next_vmem;
                o_ref_ctr_out <= next_ref_ctr;
            end
            // ��ȿ�� �Է��� ������ ��� �������ʹ� ���� ���� �����մϴ�.
            // (��, ������ũ ����� �Ź� 0���� ���µǵ��� o_spike <= next_spike; �� �� �� �ֽ��ϴ�.)
            // ���⼭�� ��ȿ�� ���� ������Ʈ�ϵ��� �����߽��ϴ�.
        end
    end

endmodule