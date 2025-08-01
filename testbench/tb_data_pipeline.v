`timescale 1ns / 1ps

//
// Module: tb_data_pipeline
// Description: An integration testbench for the data pipeline, connecting
//              spike_addr_fifo -> synapse_mem_ctrl -> synapse_memory.
//
module tb_data_pipeline;

    // --- Parameters ---
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 14;

    // --- Testbench Signals ---
    reg                         clk;
    reg                         rst_n;
    reg                         start_fetch;

    // FIFO inputs
    reg  [ADDR_WIDTH-1:0]       spike_addr_in;
    reg                         spike_valid_in;

    // Final outputs to monitor
    wire                        weight_valid_out;
    wire [DATA_WIDTH-1:0]       weight_data_out;
    wire                        fetch_done_out;

    // --- Wires to connect the modules ---
    wire [ADDR_WIDTH-1:0]       fifo_to_ctrl_addr;
    wire                        fifo_to_ctrl_valid;
    wire                        ctrl_to_fifo_rden;
    wire [DATA_WIDTH-1:0]       mem_to_ctrl_data;
    wire [ADDR_WIDTH-1:0]       ctrl_to_mem_addr;

    //================================================================
    // --- Module Instantiation ---
    //================================================================

    // 1. Input Spike FIFO
    spike_addr_fifo #(
        .DATA_WIDTH(ADDR_WIDTH),
        .DEPTH(128)
    ) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .i_wr_en(spike_valid_in),
        .i_wdata(spike_addr_in),
        .i_rd_en(ctrl_to_fifo_rden),
        .o_rdata(fifo_to_ctrl_addr),
        .o_valid(fifo_to_ctrl_valid)
    );

    // 2. Synapse Memory Controller (The DUT)
    synapse_mem_ctrl #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_ctrl (
        .clk(clk), .rst_n(rst_n),
        .i_start_fetch(start_fetch),
        .i_spike_addr_fifo_data(fifo_to_ctrl_addr),
        .i_spike_addr_fifo_valid(fifo_to_ctrl_valid),
        .o_spike_addr_fifo_rden(ctrl_to_fifo_rden),
        .i_syn_mem_rdata(mem_to_ctrl_data),
        .o_syn_mem_addr(ctrl_to_mem_addr),
        .o_weight_valid(weight_valid_out),
        .o_weight_data(weight_data_out),
        .o_fetch_done(fetch_done_out)
    );

    // 3. Synapse Memory
    synapse_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(10000),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_mem (
        .clk(clk), .rst_n(rst_n),
        .i_read_addr(ctrl_to_mem_addr),
        .o_read_weight(mem_to_ctrl_data),
        // Write port is not used in this test
        .i_write_en(1'b0),
        .i_write_addr(0),
        .i_write_data(0)
    );

    // --- Clock Generator ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Test Scenario ---
    initial begin
        $display("--- Data Pipeline Integration Test Start ---");
        
        // 1. Initialization
        rst_n = 1'b0;
        start_fetch = 1'b0;
        spike_addr_in = 0;
        spike_valid_in = 0;
        
        // Note: The synapse_memory will be initialized by its own
        // initial block with $readmemh("weight_init.hex").
        
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

        // 3. Start the controller
        #10;
        start_fetch = 1'b1;
        #10;
        start_fetch = 1'b0;
        $display("[%0t] Controller started.", $time);

        // 4. Monitor the final output
        repeat (3) begin
            wait (weight_valid_out);
            $display("[%0t] Controller output: valid weight %h", $time, weight_data_out);
        end

        // 5. Check for done signal
        wait (fetch_done_out);
        $display("[%0t] SUCCESS: Fetch done signal received.", $time);
        
        #50;
        $display("--- Test End ---");
        $finish;
    end

endmodule
