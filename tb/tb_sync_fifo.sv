// Testbench for synchronous FIFO - to be written on Day 3
// -----------------------------------------------------------------------------
// Smoke testbench for sync_fifo (Day 2). Day 3 turns this into a full
// self-checking testbench.
//  - Directed: fill, overflow, drain, underflow
//  - Random:   mixed reads/writes to exercise pointer wrap-around
//  - Checker:  reference queue model compares every read and the flags
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_sync_fifo;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;

    logic                  clk = 0;
    logic                  rst_n;
    logic                  wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data, rd_data;
    logic                  full, empty, overflow, underflow;
    logic [$clog2(DEPTH):0] count;

    sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (.*);

    always #5 clk = ~clk;

    // ---------------- Reference model and checker ----------------
    logic [DATA_WIDTH-1:0] model_q [$];
    logic [DATA_WIDTH-1:0] expected;
    int errors = 0;

    // Runs at every clock edge and sees the values from just before the edge
    always @(posedge clk) begin
        if (rst_n) begin
            // flags must match the model
            if (full !== (model_q.size() == DEPTH)) begin
                errors++; $error("full mismatch: full=%0b model size=%0d", full, model_q.size());
            end
            if (empty !== (model_q.size() == 0)) begin
                errors++; $error("empty mismatch: empty=%0b model size=%0d", empty, model_q.size());
            end
            if (count !== model_q.size()) begin
                errors++; $error("count mismatch: count=%0d model size=%0d", count, model_q.size());
            end

            // update model with the operations the DUT accepts
            if (wr_en && !full)
                model_q.push_back(wr_data);
            if (rd_en && !empty) begin
                expected = model_q.pop_front();
                #1; // rd_data is registered, so it updates just after the edge
                if (rd_data !== expected) begin
                    errors++; $error("data mismatch: got %0h expected %0h", rd_data, expected);
                end
            end
        end
    end

    // ---------------- Helper tasks ----------------
    task automatic do_reset();
        rst_n = 0; wr_en = 0; rd_en = 0; wr_data = '0;
        repeat (3) @(posedge clk);
        rst_n <= 1;
        @(posedge clk);
    endtask

    task automatic write_one(input logic [DATA_WIDTH-1:0] d);
        @(posedge clk);
        wr_en <= 1; wr_data <= d;
        @(posedge clk);
        wr_en <= 0;
    endtask

    task automatic read_one();
        @(posedge clk);
        rd_en <= 1;
        @(posedge clk);
        rd_en <= 0;
    endtask

    // ---------------- Test sequence ----------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_sync_fifo);

        do_reset();

        // 1. Fill completely
        $display("[TB] Test 1: fill FIFO");
        for (int i = 1; i <= DEPTH; i++) write_one(i);
        #1;
        if (!full)  begin errors++; $error("FIFO should be full"); end

        // 2. Write while full -> must be ignored and flag overflow
        $display("[TB] Test 2: overflow");
        write_one(8'hFF);
        #1;
        if (!overflow) begin errors++; $error("overflow flag not raised"); end

        // 3. Drain completely (checker verifies order)
        $display("[TB] Test 3: drain FIFO");
        for (int i = 1; i <= DEPTH; i++) read_one();
        @(posedge clk); #1;
        if (!empty) begin errors++; $error("FIFO should be empty"); end

        // 4. Read while empty -> underflow
        $display("[TB] Test 4: underflow");
        read_one();
        #1;
        if (!underflow) begin errors++; $error("underflow flag not raised"); end

        // 5. Random reads/writes, many more cycles than DEPTH to force wrap-around
        $display("[TB] Test 5: random traffic");
        repeat (500) begin
            @(posedge clk);
            wr_en   <= ($urandom_range(0, 99) < 60);
            rd_en   <= ($urandom_range(0, 99) < 50);
            wr_data <= $urandom;
        end
        @(posedge clk);
        wr_en <= 0; rd_en <= 0;
        repeat (3) @(posedge clk);

        if (errors == 0) $display("[TB] PASS: all checks passed");
        else             $display("[TB] FAIL: %0d errors", errors);
        $finish;
    end

    // Safety timeout
    initial begin
        #200000;
        $display("[TB] TIMEOUT");
        $finish;
    end

endmodule
