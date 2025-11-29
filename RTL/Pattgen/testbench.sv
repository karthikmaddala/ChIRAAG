// tb_design_rev_fixed.sv
`timescale 1ns/1ps
module tb_design_rev_fixed;
  import tlul_pkg::*;
  import prim_alert_pkg::*;
  import pattgen_reg_pkg::*;

  // Clock / reset
  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz
  end

  // DUT interface
  logic rst_n_i;
  tl_h2d_t tl_i;
  tl_d2h_t tl_o;

  prim_alert_pkg::alert_rx_t alert_rx_i [NumAlerts-1:0];
  prim_alert_pkg::alert_tx_t alert_tx_o [NumAlerts-1:0];

  logic pda0, pcl0, pda1, pcl1;
  logic pda0_en, pcl0_en, pda1_en, pcl1_en;
  logic intr_done0, intr_done1;

  // testbench-scoped integers
  integer i;
  integer timeout_cycles;
  integer observed_activity;

  // Instantiate DUT
  pattgen_top dut (
    .clk_i(clk),
    .rst_ni(rst_n_i),
    .tl_i(tl_i),
    .tl_o(tl_o),
    .alert_rx_i(alert_rx_i),
    .alert_tx_o(alert_tx_o),
    .cio_pda0_tx_o(pda0),
    .cio_pcl0_tx_o(pcl0),
    .cio_pda1_tx_o(pda1),
    .cio_pcl1_tx_o(pcl1),
    .cio_pda0_tx_en_o(pda0_en),
    .cio_pcl0_tx_en_o(pcl0_en),
    .cio_pda1_tx_en_o(pda1_en),
    .cio_pcl1_tx_en_o(pcl1_en),
    .intr_done_ch0_o(intr_done0),
    .intr_done_ch1_o(intr_done1)
  );

  // Init
  initial begin
    tl_i = '{a_valid:0, a_is_write:0, a_addr:0, a_data:0, a_be:0};
    alert_rx_i = '{default:0};
    rst_n_i = 1'b0;
    repeat (5) @(posedge clk);
    rst_n_i = 1'b1;
  end

  // TL write (single beat)
  task automatic tl_write(input logic [5:0] addr, input logic [31:0] data);
    begin
      @(posedge clk);
      tl_i.a_valid    <= 1'b1;
      tl_i.a_is_write <= 1'b1;
      tl_i.a_addr     <= addr;
      tl_i.a_data     <= data;
      tl_i.a_be       <= 4'hF;
      @(posedge clk);
      tl_i.a_valid    <= 1'b0;
      tl_i.a_is_write <= 1'b0;
      tl_i.a_addr     <= '0;
      tl_i.a_data     <= '0;
      tl_i.a_be       <= '0;
      @(posedge clk);
    end
  endtask

  // TL read (wait for d_valid)
  task automatic tl_read(input logic [5:0] addr, output logic [31:0] rdata, input int timeout_cycles_local = 100);
    integer j;
    begin
      @(posedge clk);
      tl_i.a_valid    <= 1'b1;
      tl_i.a_is_write <= 1'b0;
      tl_i.a_addr     <= addr;
      tl_i.a_data     <= 32'h0;
      tl_i.a_be       <= 4'h0;
      @(posedge clk);
      tl_i.a_valid    <= 1'b0;
      tl_i.a_is_write <= 1'b0;
      tl_i.a_addr     <= '0;

      rdata = 32'hDEADBEEF;
      wait_block: for (j = 0; j < timeout_cycles_local; j = j + 1) begin
        @(posedge clk);
        if (tl_o.d_valid) begin
          rdata = tl_o.d_data;
          disable wait_block;
        end
      end

      if (!tl_o.d_valid) $display("[%0t] WARNING: TL read not valid within %0d cycles", $time, timeout_cycles_local);
      @(posedge clk);
    end
  endtask

  // Main test
  initial begin
    logic [31:0] readback;

    wait (rst_n_i === 1'b1);
    $display("[%0t] Reset released, starting testbench", $time);

    // Program channel 0
    $display("[%0t] Writing DATA_CH0_0 ...", $time);
    tl_write(PATTGEN_DATA_CH0_0_OFFSET, 32'hA5A5A5A5);
    $display("[%0t] Writing DATA_CH0_1 ...", $time);
    tl_write(PATTGEN_DATA_CH0_1_OFFSET, 32'h00000000);
    $display("[%0t] Writing PREDIV_CH0 = 2 ...", $time);
    tl_write(PATTGEN_PREDIV_CH0_OFFSET, 32'd2);
    $display("[%0t] Writing SIZE (len=4 reps=2) ...", $time);
    tl_write(PATTGEN_SIZE_OFFSET, (6'd4) | (10'd2 << 6));
    $display("[%0t] Enabling channel 0 (CTRL) ...", $time);
    tl_write(PATTGEN_CTRL_OFFSET, 32'h1);

    // Read back
    tl_read(PATTGEN_PREDIV_CH0_OFFSET, readback);
    $display("[%0t] Read back PREDIV_CH0 = 0x%08h", $time, readback);

    // Observe outputs and wait for interrupt
    timeout_cycles = 2000;
    observed_activity = 0;
    for (i = 0; i < timeout_cycles; i = i + 1) begin
      @(posedge clk);
      // Use the qs signals that actually exist in u_reg (not the prim_subreg instance port names)
      if (pcl0 !== 1'bx && pda0 !== 1'bx) begin
        if (pcl0 !== dut.u_reg.ctrl_inactive_level_pcl_ch0_qs ||
            pda0 !== dut.u_reg.ctrl_inactive_level_pda_ch0_qs) begin
          observed_activity = 1;
        end
      end
      if (intr_done0) begin
        $display("[%0t] Interrupt observed: intr_done_ch0_o == 1", $time);
        break;
      end
    end

    if (!observed_activity)
      $display("[%0t] WARNING: No output activity observed on pda0/pcl0 in %0d cycles", $time, timeout_cycles);

    if (intr_done0) $display("[%0t] TEST PASS: intr_done_ch0 observed.", $time);
    else begin
      $display("[%0t] TEST FAIL: intr_done_ch0 NOT observed within timeout (%0d cycles).", $time, timeout_cycles);
      $display("Debug dump: pcl0=%b pda0=%b", pcl0, pda0);
      // Read internal reg snapshots (these qs nets exist in u_reg)
      $display(" dut.u_reg.prediv_ch0_qs = 0x%0h", dut.u_reg.prediv_ch0_qs);
      $display(" dut.u_reg.size_len_ch0_qs = 0x%0h", dut.u_reg.size_len_ch0_qs);
      $display(" dut.u_reg.size_reps_ch0_qs = 0x%0h", dut.u_reg.size_reps_ch0_qs);
    end

    // Disable channel 0
    $display("[%0t] Disabling channel 0.", $time);
    tl_write(PATTGEN_CTRL_OFFSET, 32'h0);

    #50; $display("[%0t] Testbench finished", $time);
    #10; $finish(0);
  end

  // VCD
  initial begin
    $dumpfile("tb_design_rev_fixed.vcd");
    $dumpvars(0, tb_design_rev_fixed);
  end

  // tie alerts low
  initial alert_rx_i = '{default:0};

endmodule : tb_design_rev_fixed

