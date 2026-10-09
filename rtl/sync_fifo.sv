// Synchronous FIFO design - to be written on Day 2


// -----------------------------------------------------------------------------
// Synchronous FIFO
//  - Single clock, synchronous active-low reset
//  - Parameters: DATA_WIDTH, DEPTH (must be a power of 2)
//  - Pointers carry one extra MSB to tell full from empty
//  - Read data is registered (valid the cycle after rd_en)
//  - Writes when full and reads when empty are ignored (and flagged)
// -----------------------------------------------------------------------------
module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Write side
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    // Read side
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,

    // Status
    output logic [$clog2(DEPTH):0] count,
    output logic                  overflow,   // write attempted while full
    output logic                  underflow   // read attempted while empty
);

    localparam int ADDR_W = $clog2(DEPTH);

    // Elaboration-time check: DEPTH must be a power of 2 and >= 2
    initial begin
        if (DEPTH < 2 || (DEPTH & (DEPTH - 1)) != 0)
            $fatal(1, "sync_fifo: DEPTH (%0d) must be a power of 2 and >= 2", DEPTH);
    end

    // Storage
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Pointers have ADDR_W+1 bits: lower bits index memory, MSB flags wrap-around
    logic [ADDR_W:0] wr_ptr, rd_ptr;

    // Flags
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
                   (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
    assign count = wr_ptr - rd_ptr;

    // Qualified enables: ignore illegal operations
    logic do_write, do_read;
    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    // Write logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (do_write) begin
            mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read logic (registered output)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (do_read) begin
            rd_data <= mem[rd_ptr[ADDR_W-1:0]];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

    // Error flags (registered, one-cycle pulses)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            overflow  <= wr_en && full;
            underflow <= rd_en && empty;
        end
    end

endmodule
