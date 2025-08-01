`timescale 1ns / 1ps

//
// Module: tb_neuron_pe
// Description: Unit testbench for neuron_pe, modified to match the exact
//              scenarios and behavior of the user's tb_neuron_body.
//
module tb_neuron_pe;

    // --- DUT Parameters (from user's tb_neuron_body) ---
    localparam DATA_WIDTH      = 8;
    localparam FSM_WIDTH       = 2;
    localparam SUM_WIDTH       = 16;
    localparam STATE_VEC_WIDTH = DATA_WIDTH + FSM_WIDTH + DATA_WIDTH;
    localparam THRESH          = 15;
    localparam THRESH_HIGH     = 40;
    localparam MAX_VAL         = 100;
    localparam LEAK_IDLE       = 2;
    localparam LEAK_REF        = 20;

    // --- Testbench Signals ---
    reg                         clk;
    reg                         rst_n;
    reg                         i_start;
    reg  [SUM_WIDTH-1:0]        i_mac_sum;
    reg  [STATE_VEC_WIDTH-1:0]  i_state_in; // PE의 입력을 제어

    wire [STATE_VEC_WIDTH-1:0]  o_state_out;
    wire                        o_spike;

    // --- Unpack output state for easy monitoring ---
    wire [DATA_WIDTH-1:0] o_vmem;
    wire [FSM_WIDTH-1:0]  o_fsm_state;
    assign {o_vmem, o_fsm_state, _} = o_state_out;

    // --- DUT Instantiation ---
    neuron_pe #(
        .DATA_WIDTH(DATA_WIDTH), .FSM_WIDTH(FSM_WIDTH), .SUM_WIDTH(SUM_WIDTH),
        .STATE_VEC_WIDTH(STATE_VEC_WIDTH), .THRESH(THRESH), .THRESH_HIGH(THRESH_HIGH),
        .MAX_VAL(MAX_VAL), .LEAK_IDLE(LEAK_IDLE), .LEAK_REF(LEAK_REF)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .i_start(i_start),
        .i_mac_sum(i_mac_sum),
        .i_state_in(i_state_in),
        .o_state_out(o_state_out),
        .o_spike(o_spike)
    );

    // 1. Clock Generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period (100MHz)
    end

    // 2. Test Scenario
    initial begin
        $display("=====================================================");
        $display("             Neuron PE Test Start                  ");
        $display("=====================================================");

        // Monitoring (matches user's tb_neuron_body format)
        $monitor("Time=%0t | rst_n=%b i_start=%b i_mac=%3d | vmem=%3d spike=%b | state=%d",
                  $time, rst_n, i_start, i_mac_sum, o_vmem, o_spike, o_fsm_state);

        // --- Scenario 1: Reset ---
        $display("\n--- [Scenario 1] Reset Test ---");
        i_start = 0;
        i_mac_sum = 0;
        i_state_in = 0;
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
        #10;

        // --- Scenario 2: Integration & Leak Test ---
        $display("\n--- [Scenario 2] Integration & Leak Test ---");
        i_start = 1;
        i_mac_sum = 10;
        i_state_in = 0; // Start from idle state
        #10; // PE calculates: vmem = 0 + 10 - 2 = 8
        i_state_in = o_state_out; // Feed back the result
        i_start = 0;
        #30; // vmem leaks: 8 -> 6 -> 4 -> 2
        i_state_in = o_state_out; #10;
        i_state_in = o_state_out; #10;
        i_state_in = o_state_out; #10;
        #10; // vmem leaks: 2 -> 0. vmem becomes 0
        i_state_in = o_state_out; #10;
        #10;

        // --- Scenario 3: Spike -> Absolute Refractory (based on new user logic) ---
        $display("\n--- [Scenario 3] Spike -> Absolute Refractory Period ---");
        i_start = 1;
        i_mac_sum = 20;
        i_state_in = 0; // Start from idle
        #10; // vmem = 0 + 20 - 2 = 18. (THRESH=15 exceeded) -> vmem becomes MAX_VAL(100)
        i_state_in = o_state_out;
        i_start = 0;
        #10; // S_SPIKE state. out_spike=1
        i_state_in = o_state_out;
        #10; // S_ABS_REF state. vmem = 100 - 20 = 80
        i_state_in = o_state_out;
        #10; // S_ABS_REF state. vmem = 80 - 20 = 60. (<= 70) -> transitions to REL_REF
        i_state_in = o_state_out;
        #10; // S_REL_REF state. vmem = 60 - 20 = 40
        i_state_in = o_state_out;
        #20; // Leak until vmem is 0
        i_state_in = o_state_out; #10;
        i_state_in = o_state_out; #10;
        #10; // S_IDLE state
        i_state_in = o_state_out; #10;

        // --- Scenario 4: Re-fire from Relative Refractory ---
        $display("\n--- [Scenario 4] Re-fire from Relative Refractory ---");
        i_start = 1; i_mac_sum = 20; i_state_in = 0; #10; // Spike -> MAX_VAL
        i_state_in = o_state_out; i_start = 0; #10;      // SPIKE
        i_state_in = o_state_out; #10;                   // ABS_REF, vmem=80
        i_state_in = o_state_out; #10;                   // ABS_REF, vmem=60 -> REL_REF
        i_state_in = o_state_out; #10;                   // REL_REF, vmem=40
        // Now in REL_REF, give strong input
        i_start = 1;
        i_mac_sum = 10; // vmem = 40 + 10 - 20 = 30
        #10;
        i_state_in = o_state_out; // vmem is 30, still in REL_REF
        i_mac_sum = 30; // vmem = 30 + 30 - 20 = 40. (>= THRESH_HIGH) -> MAX_VAL
        #10;
        i_state_in = o_state_out; i_start = 0; #10; // SPIKE state again
        #10;

        // --- Test End ---
        $display("\n=====================================================");
        $display("             Neuron PE Test End                    ");
        $display("=====================================================");
        $finish;
    end

endmodule
