`timescale 1ns / 1ps

module timer_core_tb;

// Parameters
parameter N = 1;
parameter CLK_PERIOD = 10; // Clock period in nanoseconds (100 MHz)

// Inputs
reg clk_i;
reg rst_ni;
reg active;
reg [11:0] prescaler;
reg [7:0] step;
reg [63:0] mtime;
reg [63:0] mtimecmp[N];

// Outputs
wire tick;
wire [63:0] mtime_d;
wire [N-1:0] intr;

// Instantiate the Unit Under Test (UUT)
timer_core #(.N(N)) uut (
    .clk_i(clk_i), 
    .rst_ni(rst_ni), 
    .active(active), 
    .prescaler(prescaler), 
    .step(step), 
    .tick(tick), 
    .mtime_d(mtime_d), 
    .mtime(mtime), 
    .mtimecmp(mtimecmp), 
    .intr(intr)
);

// Clock generation
always #(CLK_PERIOD/2) clk_i = ~clk_i;

// Initial block for simulation
initial begin
    // Initialize Inputs
    clk_i = 0;
    rst_ni = 0;
    active = 0;
    prescaler = 0;
    step = 0;
    mtime = 80;
    mtimecmp[0] = 64'd10; // Example compare value

    // Reset the system
    #20;
    rst_ni = 1;
    #20;

    // Activate timer and configure
    active = 1;
    prescaler = 12'd3; // Increment tick every 4 clock cycles
    step = 8'd1; // Increment mtime by 1 on every tick
    
    // Wait and observe
    #100;

    // Change conditions if needed, for example, adjust mtimecmp to test interrupt generation
    mtimecmp[0] = 64'd2; // Adjust compare value to generate an interrupt quickly

    // Continue simulation for more time
    #200;

    // Finish simulation
    $finish;
end

// Optional: Monitor changes
initial begin
    $monitor("Time: %t, Tick: %b, mtime: %d, mtime_d: %d, Interrupt: %b", $time, tick, mtime, mtime_d, intr[0]);
end

endmodule

