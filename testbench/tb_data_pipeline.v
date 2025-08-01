`timescale 1ns / 1ps

//
// Module: tb_pipeline_with_mac
// Description: An integration testbench for the complete data pipeline,
//              including the MAC unit. It verifies the flow:
//              FIFO -> Controller -> Memory -> MAC.
//
module tb_data_pipeline;

    // --- Parameters ---
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 14;
    localparam SUM_WIDTH  = 16;

    // --- Testbench Signals ---
    reg                         clk;
    reg                         rst_n;
    reg                         start_fetch;

    // FIFO inputs
    reg  [ADDR_WIDTH-1:0]       spike_addr_in;
    reg                         spike_valid_in;

    // MAC control
    reg                         mac_clear;
    
    // --- <<< 수정된 부분: 변수 선언 위치 이동 >>> ---
    reg [SUM_WIDTH-1:0]         expected_sum;

    // Final outputs to monitor
    wire [SUM_WIDTH-1:0]        mac_sum_out;
    wire                        fetch_done_out;

    // --- Wires to connect the modules ---
    wire [ADDR_WIDTH-1:0]       fifo_to_ctrl_addr;
    wire                        fifo_to_ctrl_valid;
    wire                        ctrl_to_fifo_rden;
    wire [DATA_WIDTH-1:0]       mem_to_ctrl_data;
    wire [ADDR_WIDTH-1:0]       ctrl_to_mem_addr;
    wire                        ctrl_to_mac_valid;
    wire [DATA_WIDTH-1:0]       ctrl_to_mac_data;

    //================================================================
    // --- Module Instantiation ---
    //================================================================

    // 1. Input Spike FIFO
    spike_addr_fifo #(
        .DATA_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .i_wr_en(spike_valid_in), .i_wdata(spike_addr_in),
        .i_rd_en(ctrl_to_fifo_rden),
        .o_rdata(fifo_to_ctrl_addr), .o_valid(fifo_to_ctrl_valid)
    );

    // 2. Synapse Memory Controller
    synapse_mem_ctrl #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_ctrl (
        .clk(clk), .rst_n(rst_n),
        .i_start_fetch(start_fetch),
        .i_spike_addr_fifo_data(fifo_to_ctrl_addr),
        .i_spike_addr_fifo_valid(fifo_to_ctrl_valid),
        .o_spike_addr_fifo_rden(ctrl_to_fifo_rden),
        .i_syn_mem_rdata(mem_to_ctrl_data),
        .o_syn_mem_addr(ctrl_to_mem_addr),
        .o_weight_valid(ctrl_to_mac_valid),
        .o_weight_data(ctrl_to_mac_data),
        .o_fetch_done(fetch_done_out)
    );

    // 3. Synapse Memory
    synapse_memory #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_mem (
        .clk(clk), .rst_n(rst_n),
        .i_read_addr(ctrl_to_mem_addr),
        .o_read_weight(mem_to_ctrl_data),
        .i_write_en(1'b0), .i_write_addr(0), .i_write_data(0)
    );

    // 4. MAC Unit
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH), .SUM_WIDTH(SUM_WIDTH)
    ) u_mac (
        .clk(clk), .rst_n(rst_n),
        .i_clear(mac_clear),
        .i_accumulate(ctrl_to_mac_valid), // 컨트롤러가 유효한 가중치를 보낼 때마다 누적
        .i_data_in(ctrl_to_mac_data),
        .o_sum(mac_sum_out)
    );

    // --- Clock Generator ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Test Scenario ---
    initial begin
        $display("--- Data Pipeline with MAC Integration Test Start ---");
        
        // 1. Initialization
        rst_n = 1'b0;
        start_fetch = 1'b0;
        spike_addr_in = 0;
        spike_valid_in = 0;
        mac_clear = 1'b1;
        
        #20;
        rst_n = 1'b1;
        $display("[%0t] Reset released.", $time);
        
        // 2. Load addresses into the FIFO
        @(posedge clk);
        spike_addr_in = 10; spike_valid_in = 1;
        @(posedge clk);
        spike_addr_in = 20; spike_valid_in = 1;
        @(posedge clk);
        spike_addr_in = 30; spike_valid_in = 1;
        @(posedge clk);
        spike_valid_in = 0;
        $display("[%0t] 3 spike addresses loaded into FIFO.", $time);

        // 3. Start the controller and clear MAC
        #10;
        mac_clear = 1'b1; // fetch 시작 직전에 MAC 초기화
        start_fetch = 1'b1;
        @(posedge clk);
        mac_clear = 1'b0;
        start_fetch = 1'b0;
        $display("[%0t] Controller started, MAC cleared.", $time);

        // 4. Wait for the operation to complete
        wait (fetch_done_out);
        $display("[%0t] Fetch done signal received.", $time);
        
        // 5. Verify the final MAC sum
        #1; // Give one delta cycle for combinational logic to settle
        expected_sum = 16'hAA + 16'hBB + 16'hCC;

        if (mac_sum_out == expected_sum) begin
            $display("SUCCESS: Final MAC sum is correct!");
            $display("Expected: %h, Got: %h", expected_sum, mac_sum_out);
        end else begin
            $error("FAILURE: Final MAC sum is incorrect!");
            $error("Expected: %h, Got: %h", expected_sum, mac_sum_out);
        end
        
        #50;
        $display("--- Test End ---");
        $finish;
    end

endmodule
