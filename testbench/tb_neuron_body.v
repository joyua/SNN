`timescale 1ns / 1ps

module tb_neuron_body;

    // DUT �Ķ���� ����
    localparam DATA_WIDTH  = 8;
    localparam THRESH      = 15;
    localparam THRESH_HIGH = 40;
    localparam OVERSHOOT   = 70;
    localparam MAX_VAL     = 100;
    localparam LEAK_IDLE   = 2;
    localparam LEAK_REF    = 20;

    // �׽�Ʈ��ġ ��ȣ ����
    reg                          clk;
    reg                          rst_n;
    reg                          in_valid;
    reg  [DATA_WIDTH-1:0]        in_mac_sum;

    wire                         out_spike;
    wire [DATA_WIDTH-1:0]        out_vmem;
    
    // DUT(Device Under Test) �ν��Ͻ�ȭ
    neuron_body #(
        .DATA_WIDTH (DATA_WIDTH),
        .THRESH     (THRESH),
        .THRESH_HIGH(THRESH_HIGH),
        .OVERSHOOT  (OVERSHOOT),
        .MAX_VAL    (MAX_VAL),
        .LEAK_IDLE  (LEAK_IDLE),
        .LEAK_REF   (LEAK_REF)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (in_valid),
        .in_mac_sum (in_mac_sum),
        .out_spike  (out_spike),
        .out_vmem   (out_vmem)
    );

    // 1. Ŭ�� ����
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns �ֱ� (100MHz)
    end

    // 2. �׽�Ʈ �ó�����
    initial begin
        $display("=====================================================");
        $display("               Neuron Body Test Start                ");
        $display("=====================================================");
        
        // ����͸�: �ùķ��̼� �� �ֿ� ��ȣ ��ȭ�� ��� ���
        // $time, rst_n, in_valid, in_mac_sum, out_vmem, out_spike, DUT�� state
        $monitor("Time=%0t | rst_n=%b in_valid=%b in_mac=%3d | vmem=%3d spike=%b | state=%d", 
                  $time, rst_n, in_valid, in_mac_sum, dut.out_vmem, out_spike, dut.state);

        // --- �ó����� 1: �ʱ�ȭ (Reset) ---
        $display("\n--- [Scenario 1] Reset Test ---");
        in_valid = 0;
        in_mac_sum = 0;
        rst_n = 1'b0; // ���� Ȱ��ȭ
        #20;
        rst_n = 1'b1; // ���� ��Ȱ��ȭ
        #10;
        
        // --- �ó����� 2: �Ϲ� ���� �� ���� �׽�Ʈ ---
        $display("\n--- [Scenario 2] Integration & Leak Test ---");
        in_valid = 1;
        in_mac_sum = 10;
        #10; // vmem = 0 + 10 - 2 = 8
        in_valid = 0;
        #30; // vmem ����: 8 -> 6 -> 4 -> 2
        #10; // vmem ����: 2 -> 0. vmem�� 0�� ��
        #10;
        
        // --- �ó����� 3: THRESH �ʰ� -> Spike �߻� (����� ������ ����) ---
        $display("\n--- [Scenario 3] Spike -> Relative Refractory Period ---");
        in_valid = 1;
        in_mac_sum = 10;
        #10; // vmem = 0 + 10 - 2 = 8
        #10; // vmem = 8 + 10 - 2 = 16. (THRESH=15 �ʰ�)
             // pre_spike_vmem�� 8+10=18�� ĸó�� (< OVERSHOOT=70)
        in_valid = 0;
        #10; // S_SPIKE ����. out_spike=1
        #10; // S_REL_REF ����. vmem = 16 - 40(LEAK_REF) -> 0
        #10; // S_IDLE ���·� ����
        #10;

        // --- �ó����� 4: OVERSHOOT �ʰ� -> Spike �߻� (������ ������ ����) ---
        $display("\n--- [Scenario 4] Overshoot Spike -> Absolute Refractory Period ---");
        in_valid = 1;
        in_mac_sum = 80;
        #10; // vmem = 0 + 80 - 2 = 78. (THRESH=15 �ʰ�)
             // pre_spike_vmem�� 80���� ĸó�� (>= OVERSHOOT=70)
        in_valid = 0;
        #10; // S_SPIKE ����. out_spike=1
        #10; // S_ABS_REF ����. vmem = 78 - 40 = 38
        #10; // S_ABS_REF ����. vmem = 38 - 40 -> 0
        #10; // S_IDLE ���·� ����
        #10;
        
        // --- �ó����� 5: �ִ밪(MAX_VAL) ��ȭ �׽�Ʈ ---
        $display("\n--- [Scenario 5] Saturation Test ---");
        in_valid = 1;
        in_mac_sum = 60;
        #10; // vmem = 0 + 60 - 2 = 58
        #10; // vmem = 58 + 60 - 2 = 116 -> 100 (MAX_VAL ��ȭ)
        #10; // vmem = 100 + 60 - 2 = 158 -> 100 (��ȭ ����)
        in_valid = 0;
        #10;

        // --- �׽�Ʈ ���� ---
        $display("\n=====================================================");
        $display("                Neuron Body Test End                 ");
        $display("=====================================================");
        $finish;
    end

endmodule