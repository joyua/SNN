`timescale 1ns / 1ps

module tb_neuron_body;

    // DUT 파라미터 정의
    localparam DATA_WIDTH  = 8;
    localparam THRESH      = 15;
    localparam THRESH_HIGH = 40;
    localparam OVERSHOOT   = 70;
    localparam MAX_VAL     = 100;
    localparam LEAK_IDLE   = 2;
    localparam LEAK_REF    = 20;

    // 테스트벤치 신호 선언
    reg                          clk;
    reg                          rst_n;
    reg                          in_valid;
    reg  [DATA_WIDTH-1:0]        in_mac_sum;

    wire                         out_spike;
    wire [DATA_WIDTH-1:0]        out_vmem;
    
    // DUT(Device Under Test) 인스턴스화
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

    // 1. 클럭 생성
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 주기 (100MHz)
    end

    // 2. 테스트 시나리오
    initial begin
        $display("=====================================================");
        $display("               Neuron Body Test Start                ");
        $display("=====================================================");
        
        // 모니터링: 시뮬레이션 중 주요 신호 변화를 계속 출력
        // $time, rst_n, in_valid, in_mac_sum, out_vmem, out_spike, DUT의 state
        $monitor("Time=%0t | rst_n=%b in_valid=%b in_mac=%3d | vmem=%3d spike=%b | state=%d", 
                  $time, rst_n, in_valid, in_mac_sum, dut.out_vmem, out_spike, dut.state);

        // --- 시나리오 1: 초기화 (Reset) ---
        $display("\n--- [Scenario 1] Reset Test ---");
        in_valid = 0;
        in_mac_sum = 0;
        rst_n = 1'b0; // 리셋 활성화
        #20;
        rst_n = 1'b1; // 리셋 비활성화
        #10;
        
        // --- 시나리오 2: 일반 누적 및 누수 테스트 ---
        $display("\n--- [Scenario 2] Integration & Leak Test ---");
        in_valid = 1;
        in_mac_sum = 10;
        #10; // vmem = 0 + 10 - 2 = 8
        in_valid = 0;
        #30; // vmem 누수: 8 -> 6 -> 4 -> 2
        #10; // vmem 누수: 2 -> 0. vmem은 0이 됨
        #10;
        
        // --- 시나리오 3: THRESH 초과 -> Spike 발생 (상대적 불응기 진입) ---
        $display("\n--- [Scenario 3] Spike -> Relative Refractory Period ---");
        in_valid = 1;
        in_mac_sum = 10;
        #10; // vmem = 0 + 10 - 2 = 8
        #10; // vmem = 8 + 10 - 2 = 16. (THRESH=15 초과)
             // pre_spike_vmem은 8+10=18로 캡처됨 (< OVERSHOOT=70)
        in_valid = 0;
        #10; // S_SPIKE 상태. out_spike=1
        #10; // S_REL_REF 상태. vmem = 16 - 40(LEAK_REF) -> 0
        #10; // S_IDLE 상태로 복귀
        #10;

        // --- 시나리오 4: OVERSHOOT 초과 -> Spike 발생 (절대적 불응기 진입) ---
        $display("\n--- [Scenario 4] Overshoot Spike -> Absolute Refractory Period ---");
        in_valid = 1;
        in_mac_sum = 80;
        #10; // vmem = 0 + 80 - 2 = 78. (THRESH=15 초과)
             // pre_spike_vmem은 80으로 캡처됨 (>= OVERSHOOT=70)
        in_valid = 0;
        #10; // S_SPIKE 상태. out_spike=1
        #10; // S_ABS_REF 상태. vmem = 78 - 40 = 38
        #10; // S_ABS_REF 상태. vmem = 38 - 40 -> 0
        #10; // S_IDLE 상태로 복귀
        #10;
        
        // --- 시나리오 5: 최대값(MAX_VAL) 포화 테스트 ---
        $display("\n--- [Scenario 5] Saturation Test ---");
        in_valid = 1;
        in_mac_sum = 60;
        #10; // vmem = 0 + 60 - 2 = 58
        #10; // vmem = 58 + 60 - 2 = 116 -> 100 (MAX_VAL 포화)
        #10; // vmem = 100 + 60 - 2 = 158 -> 100 (포화 유지)
        in_valid = 0;
        #10;

        // --- 테스트 종료 ---
        $display("\n=====================================================");
        $display("                Neuron Body Test End                 ");
        $display("=====================================================");
        $finish;
    end

endmodule