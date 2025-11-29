// design.sv
// Consolidated & corrected pattgen single-file for simulation
`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Assertion macro stubs (no-ops) - remove if you have prim_assert.sv
// -----------------------------------------------------------------------------
// define ASSERT to accept 4 args used in the file: (name, expr, clk, rst_cond)
`define ASSERT_KNOWN(name, expr)
`define ASSERT(name, expr, clk, rst_cond)
`define ASSERT_PULSE(name, sig, clk, rst_cond)
`define ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(name, regtop, alert)
`define ASSUME(name, expr)

// -----------------------------------------------------------------------------
// Packages
// -----------------------------------------------------------------------------
package tlul_pkg;
  typedef struct packed {
    logic a_valid;
    logic a_is_write;
    logic [5:0] a_addr;
    logic [31:0] a_data;
    logic [3:0] a_be;
  } tl_h2d_t;

  typedef struct packed {
    logic a_ready;
    logic d_valid;
    logic [31:0] d_data;
  } tl_d2h_t;

  parameter logic [0:0] CheckDis = 1'b0;
endpackage : tlul_pkg

package prim_alert_pkg;
  // scalar alert types (testbench-friendly)
  typedef logic alert_rx_t;
  typedef logic alert_tx_t;
endpackage : prim_alert_pkg

package pattgen_reg_pkg;
  parameter int NumAlerts = 1;

  // offsets (6-bit addresses)
  parameter logic [5:0] PATTGEN_INTR_STATE_OFFSET    = 6'h00;
  parameter logic [5:0] PATTGEN_INTR_ENABLE_OFFSET   = 6'h01;
  parameter logic [5:0] PATTGEN_INTR_TEST_OFFSET     = 6'h02;
  parameter logic [5:0] PATTGEN_ALERT_TEST_OFFSET    = 6'h03;
  parameter logic [5:0] PATTGEN_CTRL_OFFSET          = 6'h04;
  parameter logic [5:0] PATTGEN_PREDIV_CH0_OFFSET    = 6'h05;
  parameter logic [5:0] PATTGEN_PREDIV_CH1_OFFSET    = 6'h06;
  parameter logic [5:0] PATTGEN_DATA_CH0_0_OFFSET    = 6'h07;
  parameter logic [5:0] PATTGEN_DATA_CH0_1_OFFSET    = 6'h08;
  parameter logic [5:0] PATTGEN_DATA_CH1_0_OFFSET    = 6'h09;
  parameter logic [5:0] PATTGEN_DATA_CH1_1_OFFSET    = 6'h0A;
  parameter logic [5:0] PATTGEN_SIZE_OFFSET          = 6'h0B;

  // typed register wrappers
  typedef struct packed { logic q; logic qe; } reg_q_qe_1_t; // 1-bit-with-qe
  typedef struct packed { logic q; }              reg_q_1_t;   // 1-bit q
  typedef struct { logic [31:0] q; }              reg_q_32_t;  // 32-bit q (unpacked wrapper)

  // reg2hw is UNPACKED struct (contains arrays/unpacked members)
  typedef struct {
    reg_q_qe_1_t alert_test;

    struct {
      reg_q_1_t enable_ch0;
      reg_q_1_t enable_ch1;
      reg_q_1_t polarity_ch0;
      reg_q_1_t polarity_ch1;
      reg_q_1_t inactive_level_pcl_ch0;
      reg_q_1_t inactive_level_pda_ch0;
      reg_q_1_t inactive_level_pcl_ch1;
      reg_q_1_t inactive_level_pda_ch1;
    } ctrl;

    struct {
      reg_q_1_t done_ch0;
      reg_q_1_t done_ch1;
    } intr_enable;

    struct {
      reg_q_qe_1_t done_ch0;
      reg_q_qe_1_t done_ch1;
    } intr_test;

    struct {
      reg_q_1_t done_ch0;
      reg_q_1_t done_ch1;
    } intr_state;

    // 32-bit fields
    reg_q_32_t prediv_ch0;
    reg_q_32_t prediv_ch1;

    reg_q_32_t data_ch0 [2];
    reg_q_32_t data_ch1 [2];

    struct {
      logic [5:0]  len_ch0_q;
      logic [9:0]  reps_ch0_q;
      logic [5:0]  len_ch1_q;
      logic [9:0]  reps_ch1_q;
    } size;
  } pattgen_reg2hw_t;

  typedef struct {
    struct {
      struct { logic de; logic d; } done_ch0;
      struct { logic de; logic d; } done_ch1;
    } intr_state;
  } pattgen_hw2reg_t;

endpackage : pattgen_reg_pkg

package pattgen_ctrl_pkg;
  typedef struct packed {
    logic enable;
    logic polarity;
    logic inactive_level_pcl;
    logic inactive_level_pda;
    logic [31:0] prediv;
    logic [63:0] data;
    logic [5:0]  len;
    logic [9:0]  reps;
  } pattgen_chan_ctrl_t;
endpackage : pattgen_ctrl_pkg

// -----------------------------------------------------------------------------
// Primitive / helper modules (simulation stubs)
// -----------------------------------------------------------------------------
module tlul_cmd_intg_chk (
  input  tlul_pkg::tl_h2d_t tl_i,
  output logic err_o
);
  assign err_o = 1'b0;
endmodule

module tlul_rsp_intg_gen #(
  parameter EnableRspIntgGen = 0,
  parameter EnableDataIntgGen = 0
) (
  input  tlul_pkg::tl_d2h_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o
);
  assign tl_o = tl_i;
endmodule

module tlul_adapter_reg #(
  parameter int RegAw = 6,
  parameter int RegDw = 32,
  parameter EnableDataIntgGen = 0
) (
  input clk_i,
  input rst_ni,
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,
  input  logic en_ifetch_i,
  output logic intg_error_o,

  output logic we_o,
  output logic re_o,
  output logic [RegAw-1:0] addr_o,
  output logic [RegDw-1:0] wdata_o,
  output logic [RegDw/8-1:0] be_o,
  input  logic busy_i,
  input  logic [RegDw-1:0] rdata_i,
  input  logic error_i
);
  assign intg_error_o = 1'b0;
  assign tl_o.a_ready = ~busy_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      we_o <= 1'b0; re_o <= 1'b0; addr_o <= '0; wdata_o <= '0; be_o <= '0;
    end else begin
      we_o <= 1'b0; re_o <= 1'b0;
      if (tl_i.a_valid && ~busy_i) begin
        addr_o <= tl_i.a_addr;
        if (tl_i.a_is_write) begin
          we_o <= 1'b1; wdata_o <= tl_i.a_data; be_o <= tl_i.a_be;
        end else begin
          re_o <= 1'b1;
        end
      end
    end
  end

  always_comb begin
    tl_o.d_valid = re_o;
    tl_o.d_data  = rdata_i;
  end
endmodule : tlul_adapter_reg

module prim_reg_we_check #(
  parameter int OneHotWidth = 12
) (
  input clk_i,
  input rst_ni,
  input logic [OneHotWidth-1:0] oh_i,
  input logic en_i,
  output logic err_o
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) err_o <= 1'b0;
    else if (en_i) err_o <= (|oh_i) && (|((oh_i) & (oh_i - 1'b1)));
  end
endmodule : prim_reg_we_check

// prim_subreg:
//  - q is [DW-1:0] (width parameter)
//  - qs is 1-bit status (maps to q[0]) to match register-top expectations
module prim_subreg #(
  parameter int DW = 1
) (
  input clk_i,
  input rst_ni,
  input logic we,
  input logic [DW-1:0] wd,
  input logic de,
  input logic [DW-1:0] d,
  output logic qe,
  output logic [DW-1:0] q,
  output logic [DW-1:0] ds,
  output logic [DW-1:0] qs

);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) q <= '0;
    else if (we) q <= wd;
    else if (de) q <= d;
  end
  assign qs = q[0];
  assign ds = '0;
  assign qe = we;
endmodule : prim_subreg

module prim_subreg_ext #(
  parameter int DW = 1
) (
  input logic re,
  input logic we,
  input logic [DW-1:0] wd,
  input logic [DW-1:0] d,
  output logic qre,
  output logic qe,
  output logic [DW-1:0] q,
  output logic [DW-1:0] ds,
  output logic qs
);
  always_comb begin
    q = wd;
    qs = wd[0];
    qre = 1'b0;
    ds = '0;
    qe = we;
  end
endmodule : prim_subreg_ext

module prim_intr_hw #(
  parameter int Width = 1
) (
  input clk_i,
  input rst_ni,
  input  logic [Width-1:0] event_intr_i,
  input  logic [Width-1:0] reg2hw_intr_enable_q_i,
  input  logic [Width-1:0] reg2hw_intr_test_q_i,
  input  logic [Width-1:0] reg2hw_intr_test_qe_i,
  input  logic [Width-1:0] reg2hw_intr_state_q_i,
  output logic [Width-1:0] hw2reg_intr_state_de_o,
  output logic [Width-1:0] hw2reg_intr_state_d_o,
  output logic [Width-1:0] intr_o
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      intr_o <= '0;
      hw2reg_intr_state_de_o <= '0;
      hw2reg_intr_state_d_o <= '0;
    end else begin
      intr_o <= (event_intr_i & reg2hw_intr_enable_q_i) | reg2hw_intr_test_q_i;
      hw2reg_intr_state_de_o <= event_intr_i;
      hw2reg_intr_state_d_o <= event_intr_i;
    end
  end
endmodule : prim_intr_hw

module prim_alert_sender #(
  parameter logic AsyncOn = 1'b1,
  parameter int SkewCycles = 1,
  parameter logic IsFatal = 1'b1
) (
  input clk_i,
  input rst_ni,
  input alert_test_i,
  input alert_req_i,
  output alert_ack_o,
  output alert_state_o,
  input prim_alert_pkg::alert_rx_t alert_rx_i,
  output prim_alert_pkg::alert_tx_t alert_tx_o
);
  assign alert_tx_o = alert_test_i | alert_req_i | alert_rx_i;
  assign alert_ack_o = 1'b0;
  assign alert_state_o = alert_tx_o;
endmodule : prim_alert_sender

// -----------------------------------------------------------------------------
// pattgen_chan (full implementation copied from the original source)
// -----------------------------------------------------------------------------
module pattgen_chan
  import pattgen_ctrl_pkg::*;
(
  input                       clk_i,
  input                       rst_ni,
  input  pattgen_chan_ctrl_t  ctrl_i,
  output logic                pda_o,
  output logic                pcl_o,
  output logic                event_done_o
);

  logic        enable;
  logic        polarity_q;
  logic        inactive_level_pcl_q;
  logic        inactive_level_pda_q;
  logic [31:0] prediv_q;
  logic [63:0] data_q;
  logic [5:0]  len_q;
  logic [9:0]  reps_q;

  logic        clk_en;
  logic        pcl_int_d;
  logic        pcl_int_q;
  logic [31:0] clk_cnt_d;
  logic [31:0] clk_cnt_q;
  logic        prediv_clk_rollover;

  logic        bit_cnt_en;
  logic [5:0]  bit_cnt_d;
  logic [5:0]  bit_cnt_q;

  logic        rep_cnt_en;
  logic [9:0]  rep_cnt_d;
  logic [9:0]  rep_cnt_q;

  logic        complete_en;
  logic        complete_d;
  logic        complete_q;
  logic        complete_q2;

  logic        active, active_d, active_q;

  // only accept new control signals when
  // enable is deasserted
  assign enable = ctrl_i.enable;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      polarity_q           <=  1'h0;
      inactive_level_pcl_q <=  1'h0;
      inactive_level_pda_q <=  1'h0;
      prediv_q             <= 32'h0;
      data_q               <= 64'h0;
      len_q                <=  6'h0;
      reps_q               <= 10'h0;
    end else begin
      polarity_q           <= enable ? polarity_q           : ctrl_i.polarity;
      inactive_level_pcl_q <= enable ? inactive_level_pcl_q : ctrl_i.inactive_level_pcl;
      inactive_level_pda_q <= enable ? inactive_level_pda_q : ctrl_i.inactive_level_pda;
      prediv_q             <= enable ? prediv_q             : ctrl_i.prediv;
      data_q               <= enable ? data_q               : ctrl_i.data;
      len_q                <= enable ? len_q                : ctrl_i.len;
      reps_q               <= enable ? reps_q               : ctrl_i.reps;
    end
  end

  // Drive pcl_o and pda_o directly from FF, so that they don't glitch.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pcl_o <= 1'b0;
      pda_o <= 1'b0;
    end else begin
      pcl_o <= active ? (polarity_q ? ~pcl_int_q : pcl_int_q)
                      : inactive_level_pcl_q;
      pda_o <= active ? data_q[bit_cnt_q]
                      : inactive_level_pda_q;
    end
  end

  // Hold the prediv counter and internal clock (PCL) once the previous pattern is complete
  assign clk_en = ~complete_q;

  // Predivision Counter -> Create an internal pulse (prediv_clk_rollover) which advances the
  // pattern generation state at the input clk frequency scaled down by the predivider.
  assign prediv_clk_rollover = (clk_cnt_q == prediv_q);
  assign clk_cnt_d = (!enable) ? 32'h0:
                     prediv_clk_rollover ? 32'h0 : // Rollover
                     (clk_cnt_q + 32'h1);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      clk_cnt_q <= 32'h0;
    end else begin
      clk_cnt_q <= clk_en ? clk_cnt_d : clk_cnt_q;
    end
  end

  // Generate an internal pattern clock (PCL)
  // - PCL toggles each time the predivider counter (clk_cnt_q) wraps.
  // - The internal PCL is zero at the start of the pattern and for the first period, only toggling
  //   at the end of the first period.
  // - The internal PCL is inverted at the output flop if configured to do so by the polarity.
  assign pcl_int_d = (!enable) ? 1'h0 :
                     prediv_clk_rollover ? ~pcl_int_q : // Rollover
                     pcl_int_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pcl_int_q <= 1'h0;
    end else begin
      pcl_int_q <= clk_en ? pcl_int_d : pcl_int_q;
    end
  end

  // Increment through bits of the pattern register, wrapping when the configured length is
  // reached. The index then muxes the current bit to the output with 'data_q[bit_cnt_q]'.
  // - Only update just before the falling edge of pcl_int
  // - Reset to zero immediately and do not increment when enable is inactive.
  assign bit_cnt_en = (pcl_int_q & prediv_clk_rollover) | (~enable);
  assign bit_cnt_d  = (!enable) ? 6'h0 :
                      (bit_cnt_q == len_q) ? 6'h0 : // Rollover
                      bit_cnt_q + 6'h1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      bit_cnt_q <= 6'h0;
    end else begin
      bit_cnt_q <= bit_cnt_en ? bit_cnt_d : bit_cnt_q;
    end
  end

  // Increment a counter for the number of times the pattern data is repeated within a single
  // activation. When the configured reps count is reached, the END state for this activation is
  // reached by signaling completion, and the counter resets.
  // - Increment as bit_cnt_q rolls over to zero.
  // - Reset to zero immediately and do not increment when enable is inactive.
  assign rep_cnt_en = (bit_cnt_en & (bit_cnt_q == len_q)) | (~enable);
  assign rep_cnt_d  = (!enable) ? 10'h0 :
                      (rep_cnt_q == reps_q) ? 10'h0 : // Rollover
                      rep_cnt_q + 10'h1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rep_cnt_q <= 10'h0;
    end else begin
      rep_cnt_q <= rep_cnt_en ? rep_cnt_d : rep_cnt_q;
    end
  end

  // Set the completion signal (complete_q) when rep_cnt reaches the configured limit and rolls
  // over to zero.
  // Clear / reset to zero when enable goes inactive.
  assign complete_en = (rep_cnt_en & (rep_cnt_q == reps_q)) | (~enable);
  assign complete_d  = (!enable) ? 1'h0 : 1'h1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      complete_q  <= 1'h0;
      complete_q2 <= 1'h0;
    end else begin
      complete_q  <= complete_en ? complete_d : complete_q;
      complete_q2 <= complete_q;
    end
  end

  // Trigger the event-type interrupt upon completion of the pattern.
  assign event_done_o = complete_q & ~complete_q2;

  // Track the state of the pattern generation with the 'active' signal (IDLE/END=0:ACTIVE=1)
  // _Transitions_
  // IDLE   -> (enable -> 1)     -> ACTIVE
  // ACTIVE -> (complete_q -> 1) -> END
  // ACTIVE -> (enable -> 0)     -> IDLE
  // END    -> (enable -> 0)     -> IDLE
  assign active_d = complete_q ? 1'b0 : // clearing on completion takes precedence
                    enable     ? 1'b1 : // set to active when enabled (and not complete)
                    active_q;           // otherwise hold
  assign active = enable ? active_d : active_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_q <= 1'b0;
    end else begin
      active_q <= active_d;
    end
  end

endmodule : pattgen_chan

// -----------------------------------------------------------------------------
// pattgen_core
// -----------------------------------------------------------------------------
module pattgen_core
  import pattgen_reg_pkg::*;
  import pattgen_ctrl_pkg::*;
(
  input                   clk_i,
  input                   rst_ni,
  input  pattgen_reg2hw_t reg2hw,
  output pattgen_hw2reg_t hw2reg,

  output logic            pda0_tx_o,
  output logic            pcl0_tx_o,
  output logic            pda1_tx_o,
  output logic            pcl1_tx_o,

  output logic            intr_done_ch0_o,
  output logic            intr_done_ch1_o
);

  logic event_done_ch0;
  logic event_done_ch1;

  pattgen_chan_ctrl_t ch0_ctrl;
  pattgen_chan_ctrl_t ch1_ctrl;

  // map reg2hw fields (use .q member widths as defined)
  assign ch0_ctrl.enable             = reg2hw.ctrl.enable_ch0.q;
  assign ch0_ctrl.polarity           = reg2hw.ctrl.polarity_ch0.q;
  assign ch0_ctrl.inactive_level_pcl = reg2hw.ctrl.inactive_level_pcl_ch0.q;
  assign ch0_ctrl.inactive_level_pda = reg2hw.ctrl.inactive_level_pda_ch0.q;
  assign ch0_ctrl.data[63:32]        = reg2hw.data_ch0[1].q;
  assign ch0_ctrl.data[31:0]         = reg2hw.data_ch0[0].q;
  assign ch0_ctrl.prediv             = reg2hw.prediv_ch0.q;
  assign ch0_ctrl.len                = reg2hw.size.len_ch0_q;
  assign ch0_ctrl.reps               = reg2hw.size.reps_ch0_q;

  assign ch1_ctrl.enable             = reg2hw.ctrl.enable_ch1.q;
  assign ch1_ctrl.polarity           = reg2hw.ctrl.polarity_ch1.q;
  assign ch1_ctrl.inactive_level_pcl = reg2hw.ctrl.inactive_level_pcl_ch1.q;
  assign ch1_ctrl.inactive_level_pda = reg2hw.ctrl.inactive_level_pda_ch1.q;
  assign ch1_ctrl.data[63:32]        = reg2hw.data_ch1[1].q;
  assign ch1_ctrl.data[31:0]         = reg2hw.data_ch1[0].q;
  assign ch1_ctrl.prediv             = reg2hw.prediv_ch1.q;
  assign ch1_ctrl.len                = reg2hw.size.len_ch1_q;
  assign ch1_ctrl.reps               = reg2hw.size.reps_ch1_q;

  pattgen_chan chan0 (
    .clk_i,
    .rst_ni,
    .ctrl_i       (ch0_ctrl),
    .pda_o        (pda0_tx_o),
    .pcl_o        (pcl0_tx_o),
    .event_done_o (event_done_ch0)
  );

  pattgen_chan chan1 (
    .clk_i,
    .rst_ni,
    .ctrl_i       (ch1_ctrl),
    .pda_o        (pda1_tx_o),
    .pcl_o        (pcl1_tx_o),
    .event_done_o (event_done_ch1)
  );

  prim_intr_hw #(.Width(1)) intr_hw_done_ch0 (
    .clk_i,
    .rst_ni,
    .event_intr_i           (event_done_ch0),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.done_ch0.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.done_ch0.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.done_ch0.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.done_ch0.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.done_ch0.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.done_ch0.d),
    .intr_o                 (intr_done_ch0_o)
  );

   prim_intr_hw #(.Width(1)) intr_hw_done_ch1 (
    .clk_i,
    .rst_ni,
    .event_intr_i           (event_done_ch1),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.done_ch1.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.done_ch1.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.done_ch1.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.done_ch1.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.done_ch1.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.done_ch1.d),
    .intr_o                 (intr_done_ch1_o)
  );

  // unused registers tieoff to avoid lint complaints
  logic unused_reg;
  assign unused_reg = ^reg2hw.alert_test.q;

endmodule : pattgen_core

// -----------------------------------------------------------------------------
// pattgen_reg_top (corrected wiring and widths)
// -----------------------------------------------------------------------------
module pattgen_reg_top (
  input clk_i,
  input rst_ni,
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,
  // To HW
  output pattgen_reg_pkg::pattgen_reg2hw_t reg2hw, // Write
  input  pattgen_reg_pkg::pattgen_hw2reg_t hw2reg, // Read

  // Integrity check errors
  output logic intg_err_o
);
  import pattgen_reg_pkg::* ;

  localparam int AW = 6;
  localparam int DW = 32;
  localparam int DBW = DW/8;                    // Byte Width

  // register signals
  logic           reg_we;
  logic           reg_re;
  logic [AW-1:0]  reg_addr;
  logic [DW-1:0]  reg_wdata;
  logic [DBW-1:0] reg_be;
  logic [DW-1:0]  reg_rdata;
  logic           reg_error;

  logic          addrmiss, wr_err;

  logic [DW-1:0] reg_rdata_next;
  logic reg_busy;

  tlul_pkg::tl_h2d_t tl_reg_h2d;
  tlul_pkg::tl_d2h_t tl_reg_d2h;


  // incoming payload check
  logic intg_err;
  tlul_cmd_intg_chk u_chk (
    .tl_i(tl_i),
    .err_o(intg_err)
  );

  // also check for spurious write enables
  logic reg_we_err;
  logic [11:0] reg_we_check;
  prim_reg_we_check #(
    .OneHotWidth(12)
  ) u_prim_reg_we_check (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .oh_i  (reg_we_check),
    .en_i  (reg_we && !addrmiss),
    .err_o (reg_we_err)
  );

  logic err_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      err_q <= '0;
    end else if (intg_err || reg_we_err) begin
      err_q <= 1'b1;
    end
  end

  // integrity error output is permanent and should be used for alert generation
  // register errors are transactional
  assign intg_err_o = err_q | intg_err | reg_we_err;

  // outgoing integrity generation
  tlul_pkg::tl_d2h_t tl_o_pre;
  tlul_rsp_intg_gen #(
    .EnableRspIntgGen(1),
    .EnableDataIntgGen(1)
  ) u_rsp_intg_gen (
    .tl_i(tl_o_pre),
    .tl_o(tl_o)
  );

  assign tl_reg_h2d = tl_i;
  assign tl_o_pre   = tl_reg_d2h;

  tlul_adapter_reg #(
    .RegAw(AW),
    .RegDw(DW),
    .EnableDataIntgGen(0)
  ) u_reg_if (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .tl_i (tl_reg_h2d),
    .tl_o (tl_reg_d2h),

    .en_ifetch_i(1'b0),
    .intg_error_o(),

    .we_o    (reg_we),
    .re_o    (reg_re),
    .addr_o  (reg_addr),
    .wdata_o (reg_wdata),
    .be_o    (reg_be),
    .busy_i  (reg_busy),
    .rdata_i (reg_rdata),
    .error_i (reg_error)
  );

  // cdc oversampling signals

  assign reg_rdata = reg_rdata_next ;
  assign reg_error = addrmiss | wr_err | intg_err;

  // Define SW related signals
  // Format: <reg>_<field>_{wd|we|qs}
  //        or <reg>_{wd|we|qs} if field == 1 or 0
  logic intr_state_we;
  logic intr_state_done_ch0_qs;
  logic intr_state_done_ch0_wd;
  logic intr_state_done_ch1_qs;
  logic intr_state_done_ch1_wd;
  logic intr_enable_we;
  logic intr_enable_done_ch0_qs;
  logic intr_enable_done_ch0_wd;
  logic intr_enable_done_ch1_qs;
  logic intr_enable_done_ch1_wd;
  logic intr_test_we;
  logic intr_test_done_ch0_wd;
  logic intr_test_done_ch1_wd;
  logic alert_test_we;
  logic alert_test_wd;
  logic ctrl_we;
  logic ctrl_enable_ch0_qs;
  logic ctrl_enable_ch0_wd;
  logic ctrl_enable_ch1_qs;
  logic ctrl_enable_ch1_wd;
  logic ctrl_polarity_ch0_qs;
  logic ctrl_polarity_ch0_wd;
  logic ctrl_polarity_ch1_qs;
  logic ctrl_polarity_ch1_wd;
  logic ctrl_inactive_level_pcl_ch0_qs;
  logic ctrl_inactive_level_pcl_ch0_wd;
  logic ctrl_inactive_level_pda_ch0_qs;
  logic ctrl_inactive_level_pda_ch0_wd;
  logic ctrl_inactive_level_pcl_ch1_qs;
  logic ctrl_inactive_level_pcl_ch1_wd;
  logic ctrl_inactive_level_pda_ch1_qs;
  logic ctrl_inactive_level_pda_ch1_wd;
  logic prediv_ch0_we;
  logic [31:0] prediv_ch0_qs;
  logic [31:0] prediv_ch0_wd;
  logic prediv_ch1_we;
  logic [31:0] prediv_ch1_qs;
  logic [31:0] prediv_ch1_wd;
  logic data_ch0_0_we;
  logic [31:0] data_ch0_0_qs;
  logic [31:0] data_ch0_0_wd;
  logic data_ch0_1_we;
  logic [31:0] data_ch0_1_qs;
  logic [31:0] data_ch0_1_wd;
  logic data_ch1_0_we;
  logic [31:0] data_ch1_0_qs;
  logic [31:0] data_ch1_0_wd;
  logic data_ch1_1_we;
  logic [31:0] data_ch1_1_qs;
  logic [31:0] data_ch1_1_wd;
  logic size_we;
  logic [5:0] size_len_ch0_qs;
  logic [5:0] size_len_ch0_wd;
  logic [9:0] size_reps_ch0_qs;
  logic [9:0] size_reps_ch0_wd;
  logic [5:0] size_len_ch1_qs;
  logic [5:0] size_len_ch1_wd;
  logic [9:0] size_reps_ch1_qs;
  logic [9:0] size_reps_ch1_wd;

  // Register instances (full prim_subreg / prim_subreg_ext instantiations)
  // R[intr_state]: V(False)
  //   F[done_ch0]: 0:0
  prim_subreg #(.DW(1)) u_intr_state_done_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(intr_state_we), .wd(intr_state_done_ch0_wd),
    .de(hw2reg.intr_state.done_ch0.de), .d(hw2reg.intr_state.done_ch0.d),
    .qe(), .q(reg2hw.intr_state.done_ch0.q), .ds(), .qs(intr_state_done_ch0_qs)
  );

  //   F[done_ch1]: 1:1
  prim_subreg #(.DW(1)) u_intr_state_done_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(intr_state_we), .wd(intr_state_done_ch1_wd),
    .de(hw2reg.intr_state.done_ch1.de), .d(hw2reg.intr_state.done_ch1.d),
    .qe(), .q(reg2hw.intr_state.done_ch1.q), .ds(), .qs(intr_state_done_ch1_qs)
  );

  // R[intr_enable]
  prim_subreg #(.DW(1)) u_intr_enable_done_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(intr_enable_we), .wd(intr_enable_done_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.intr_enable.done_ch0.q), .ds(), .qs(intr_enable_done_ch0_qs)
  );

  prim_subreg #(.DW(1)) u_intr_enable_done_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(intr_enable_we), .wd(intr_enable_done_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.intr_enable.done_ch1.q), .ds(), .qs(intr_enable_done_ch1_qs)
  );

  // R[intr_test]
  logic intr_test_qe;
  logic [1:0] intr_test_flds_we;
  assign intr_test_qe = &intr_test_flds_we;
  prim_subreg_ext #(.DW(1)) u_intr_test_done_ch0 (
    .re(1'b0), .we(intr_test_we), .wd(intr_test_done_ch0_wd), .d('0),
    .qre(), .qe(intr_test_flds_we[0]), .q(reg2hw.intr_test.done_ch0.q), .ds(), .qs()
  );
  assign reg2hw.intr_test.done_ch0.qe = intr_test_qe;

  prim_subreg_ext #(.DW(1)) u_intr_test_done_ch1 (
    .re(1'b0), .we(intr_test_we), .wd(intr_test_done_ch1_wd), .d('0),
    .qre(), .qe(intr_test_flds_we[1]), .q(reg2hw.intr_test.done_ch1.q), .ds(), .qs()
  );
  assign reg2hw.intr_test.done_ch1.qe = intr_test_qe;

  // R[alert_test]
  logic alert_test_qe;
  logic [0:0] alert_test_flds_we;
  assign alert_test_qe = &alert_test_flds_we;
  prim_subreg_ext #(.DW(1)) u_alert_test (
    .re(1'b0), .we(alert_test_we), .wd(alert_test_wd), .d('0),
    .qre(), .qe(alert_test_flds_we[0]), .q(reg2hw.alert_test.q), .ds(), .qs()
  );
  assign reg2hw.alert_test.qe = alert_test_qe;

  // R[ctrl] fields
  prim_subreg #(.DW(1)) u_ctrl_enable_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_enable_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.enable_ch0.q), .ds(), .qs(ctrl_enable_ch0_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_enable_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_enable_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.enable_ch1.q), .ds(), .qs(ctrl_enable_ch1_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_polarity_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_polarity_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.polarity_ch0.q), .ds(), .qs(ctrl_polarity_ch0_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_polarity_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_polarity_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.polarity_ch1.q), .ds(), .qs(ctrl_polarity_ch1_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_inactive_level_pcl_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_inactive_level_pcl_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.inactive_level_pcl_ch0.q), .ds(), .qs(ctrl_inactive_level_pcl_ch0_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_inactive_level_pda_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_inactive_level_pda_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.inactive_level_pda_ch0.q), .ds(), .qs(ctrl_inactive_level_pda_ch0_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_inactive_level_pcl_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_inactive_level_pcl_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.inactive_level_pcl_ch1.q), .ds(), .qs(ctrl_inactive_level_pcl_ch1_qs)
  );

  prim_subreg #(.DW(1)) u_ctrl_inactive_level_pda_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(ctrl_we), .wd(ctrl_inactive_level_pda_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.ctrl.inactive_level_pda_ch1.q), .ds(), .qs(ctrl_inactive_level_pda_ch1_qs)
  );

  // R[prediv_ch0] and prediv_ch1 (32-bit)
  prim_subreg #(.DW(32)) u_prediv_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(prediv_ch0_we), .wd(prediv_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.prediv_ch0.q), .ds(), .qs(prediv_ch0_qs)
  );

  prim_subreg #(.DW(32)) u_prediv_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(prediv_ch1_we), .wd(prediv_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.prediv_ch1.q), .ds(), .qs(prediv_ch1_qs)
  );

  // data_ch0 and data_ch1 subregisters
  prim_subreg #(.DW(32)) u_data_ch0_0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(data_ch0_0_we), .wd(data_ch0_0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.data_ch0[0].q), .ds(), .qs(data_ch0_0_qs)
  );

  prim_subreg #(.DW(32)) u_data_ch0_1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(data_ch0_1_we), .wd(data_ch0_1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.data_ch0[1].q), .ds(), .qs(data_ch0_1_qs)
  );

  prim_subreg #(.DW(32)) u_data_ch1_0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(data_ch1_0_we), .wd(data_ch1_0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.data_ch1[0].q), .ds(), .qs(data_ch1_0_qs)
  );

  prim_subreg #(.DW(32)) u_data_ch1_1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(data_ch1_1_we), .wd(data_ch1_1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.data_ch1[1].q), .ds(), .qs(data_ch1_1_qs)
  );

  // R[size] fields
  prim_subreg #(.DW(6)) u_size_len_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(size_we), .wd(size_len_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.size.len_ch0_q), .ds(), .qs(size_len_ch0_qs)
  );

  prim_subreg #(.DW(10)) u_size_reps_ch0 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(size_we), .wd(size_reps_ch0_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.size.reps_ch0_q), .ds(), .qs(size_reps_ch0_qs)
  );

  prim_subreg #(.DW(6)) u_size_len_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(size_we), .wd(size_len_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.size.len_ch1_q), .ds(), .qs(size_len_ch1_qs)
  );

  prim_subreg #(.DW(10)) u_size_reps_ch1 (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .we(size_we), .wd(size_reps_ch1_wd),
    .de(1'b0), .d('0),
    .qe(), .q(reg2hw.size.reps_ch1_q), .ds(), .qs(size_reps_ch1_qs)
  );

  logic [11:0] addr_hit;
  always_comb begin
    addr_hit[ 0] = (reg_addr == PATTGEN_INTR_STATE_OFFSET);
    addr_hit[ 1] = (reg_addr == PATTGEN_INTR_ENABLE_OFFSET);
    addr_hit[ 2] = (reg_addr == PATTGEN_INTR_TEST_OFFSET);
    addr_hit[ 3] = (reg_addr == PATTGEN_ALERT_TEST_OFFSET);
    addr_hit[ 4] = (reg_addr == PATTGEN_CTRL_OFFSET);
    addr_hit[ 5] = (reg_addr == PATTGEN_PREDIV_CH0_OFFSET);
    addr_hit[ 6] = (reg_addr == PATTGEN_PREDIV_CH1_OFFSET);
    addr_hit[ 7] = (reg_addr == PATTGEN_DATA_CH0_0_OFFSET);
    addr_hit[ 8] = (reg_addr == PATTGEN_DATA_CH0_1_OFFSET);
    addr_hit[ 9] = (reg_addr == PATTGEN_DATA_CH1_0_OFFSET);
    addr_hit[10] = (reg_addr == PATTGEN_DATA_CH1_1_OFFSET);
    addr_hit[11] = (reg_addr == PATTGEN_SIZE_OFFSET);
  end

  assign addrmiss = (reg_re || reg_we) ? ~|addr_hit : 1'b0 ;

  // Check sub-word write is permitted
  always_comb begin
    wr_err = (reg_we &
              ((addr_hit[ 0] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 1] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 2] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 3] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 4] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 5] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 6] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 7] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 8] & (|(6'h0 & ~reg_be))) |
               (addr_hit[ 9] & (|(6'h0 & ~reg_be))) |
               (addr_hit[10] & (|(6'h0 & ~reg_be))) |
               (addr_hit[11] & (|(6'h0 & ~reg_be)))));
  end

  // Generate write-enables
  assign intr_state_we = addr_hit[0] & reg_we & !reg_error;

  assign intr_state_done_ch0_wd = reg_wdata[0];

  assign intr_state_done_ch1_wd = reg_wdata[1];
  assign intr_enable_we = addr_hit[1] & reg_we & !reg_error;

  assign intr_enable_done_ch0_wd = reg_wdata[0];

  assign intr_enable_done_ch1_wd = reg_wdata[1];
  assign intr_test_we = addr_hit[2] & reg_we & !reg_error;

  assign intr_test_done_ch0_wd = reg_wdata[0];

  assign intr_test_done_ch1_wd = reg_wdata[1];
  assign alert_test_we = addr_hit[3] & reg_we & !reg_error;

  assign alert_test_wd = reg_wdata[0];
  assign ctrl_we = addr_hit[4] & reg_we & !reg_error;

  assign ctrl_enable_ch0_wd = reg_wdata[0];

  assign ctrl_enable_ch1_wd = reg_wdata[1];

  assign ctrl_polarity_ch0_wd = reg_wdata[2];

  assign ctrl_polarity_ch1_wd = reg_wdata[3];

  assign ctrl_inactive_level_pcl_ch0_wd = reg_wdata[4];

  assign ctrl_inactive_level_pda_ch0_wd = reg_wdata[5];

  assign ctrl_inactive_level_pcl_ch1_wd = reg_wdata[6];

  assign ctrl_inactive_level_pda_ch1_wd = reg_wdata[7];
  assign prediv_ch0_we = addr_hit[5] & reg_we & !reg_error;

  assign prediv_ch0_wd = reg_wdata[31:0];
  assign prediv_ch1_we = addr_hit[6] & reg_we & !reg_error;

  assign prediv_ch1_wd = reg_wdata[31:0];
  assign data_ch0_0_we = addr_hit[7] & reg_we & !reg_error;

  assign data_ch0_0_wd = reg_wdata[31:0];
  assign data_ch0_1_we = addr_hit[8] & reg_we & !reg_error;

  assign data_ch0_1_wd = reg_wdata[31:0];
  assign data_ch1_0_we = addr_hit[9] & reg_we & !reg_error;

  assign data_ch1_0_wd = reg_wdata[31:0];
  assign data_ch1_1_we = addr_hit[10] & reg_we & !reg_error;

  assign data_ch1_1_wd = reg_wdata[31:0];
  assign size_we = addr_hit[11] & reg_we & !reg_error;

  assign size_len_ch0_wd = reg_wdata[5:0];

  assign size_reps_ch0_wd = reg_wdata[15:6];

  assign size_len_ch1_wd = reg_wdata[21:16];

  assign size_reps_ch1_wd = reg_wdata[31:22];

  // Assign write-enables to checker logic vector.
  always_comb begin
    reg_we_check[0] = intr_state_we;
    reg_we_check[1] = intr_enable_we;
    reg_we_check[2] = intr_test_we;
    reg_we_check[3] = alert_test_we;
    reg_we_check[4] = ctrl_we;
    reg_we_check[5] = prediv_ch0_we;
    reg_we_check[6] = prediv_ch1_we;
    reg_we_check[7] = data_ch0_0_we;
    reg_we_check[8] = data_ch0_1_we;
    reg_we_check[9] = data_ch1_0_we;
    reg_we_check[10] = data_ch1_1_we;
    reg_we_check[11] = size_we;
  end

  // Read data return
  always_comb begin
    reg_rdata_next = '0;
    unique case (1'b1)
      addr_hit[0]: begin
        reg_rdata_next[0] = intr_state_done_ch0_qs;
        reg_rdata_next[1] = intr_state_done_ch1_qs;
      end

      addr_hit[1]: begin
        reg_rdata_next[0] = intr_enable_done_ch0_qs;
        reg_rdata_next[1] = intr_enable_done_ch1_qs;
      end

      addr_hit[2]: begin
        reg_rdata_next[0] = '0;
        reg_rdata_next[1] = '0;
      end

      addr_hit[3]: begin
        reg_rdata_next[0] = '0;
      end

      addr_hit[4]: begin
        reg_rdata_next[0] = ctrl_enable_ch0_qs;
        reg_rdata_next[1] = ctrl_enable_ch1_qs;
        reg_rdata_next[2] = ctrl_polarity_ch0_qs;
        reg_rdata_next[3] = ctrl_polarity_ch1_qs;
        reg_rdata_next[4] = ctrl_inactive_level_pcl_ch0_qs;
        reg_rdata_next[5] = ctrl_inactive_level_pda_ch0_qs;
        reg_rdata_next[6] = ctrl_inactive_level_pcl_ch1_qs;
        reg_rdata_next[7] = ctrl_inactive_level_pda_ch1_qs;
      end

      addr_hit[5]: begin
        reg_rdata_next[31:0] = prediv_ch0_qs;
      end

      addr_hit[6]: begin
        reg_rdata_next[31:0] = prediv_ch1_qs;
      end

      addr_hit[7]: begin
        reg_rdata_next[31:0] = data_ch0_0_qs;
      end

      addr_hit[8]: begin
        reg_rdata_next[31:0] = data_ch0_1_qs;
      end

      addr_hit[9]: begin
        reg_rdata_next[31:0] = data_ch1_0_qs;
      end

      addr_hit[10]: begin
        reg_rdata_next[31:0] = data_ch1_1_qs;
      end

      addr_hit[11]: begin
        reg_rdata_next[5:0] = size_len_ch0_qs;
        reg_rdata_next[15:6] = size_reps_ch0_qs;
        reg_rdata_next[21:16] = size_len_ch1_qs;
        reg_rdata_next[31:22] = size_reps_ch1_qs;
      end

      default: begin
        reg_rdata_next = '1;
      end
    endcase
  end

  // shadow busy
  logic shadow_busy;
  assign shadow_busy = 1'b0;

  // register busy
  assign reg_busy = shadow_busy;

  // Unused signal tieoff

  // wdata / byte enable are not always fully used
  // add a blanket unused statement to handle lint waivers
  logic unused_wdata;
  logic unused_be;
  assign unused_wdata = ^reg_wdata;
  assign unused_be = ^reg_be;

  // Assertions for Register Interface
  `ASSERT_PULSE(wePulse, reg_we, clk_i, !rst_ni)
  `ASSERT_PULSE(rePulse, reg_re, clk_i, !rst_ni)

  `ASSERT(reAfterRv, $rose(reg_re || reg_we) |=> tl_o_pre.d_valid, clk_i, !rst_ni)

  `ASSERT(en2addrHit, (reg_we || reg_re) |-> $onehot0(addr_hit), clk_i, !rst_ni)

endmodule : pattgen_reg_top

// ------------------------- Replace pattgen_top with this ------------------------
module pattgen_top
  import pattgen_reg_pkg::*;
  import prim_alert_pkg::*;
(
  input clk_i,
  input rst_ni,
  input tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // Unpacked alert arrays to match your testbench
  input  prim_alert_pkg::alert_rx_t alert_rx_i [NumAlerts-1:0],
  output prim_alert_pkg::alert_tx_t alert_tx_o [NumAlerts-1:0],

  output logic cio_pda0_tx_o,
  output logic cio_pcl0_tx_o,
  output logic cio_pda1_tx_o,
  output logic cio_pcl1_tx_o,
  output logic cio_pda0_tx_en_o,
  output logic cio_pcl0_tx_en_o,
  output logic cio_pda1_tx_en_o,
  output logic cio_pcl1_tx_en_o,

  output logic intr_done_ch0_o,
  output logic intr_done_ch1_o
);

  pattgen_reg2hw_t reg2hw;
  pattgen_hw2reg_t hw2reg;

  // internal signal to capture integrity error from register top
  logic reg_intg_err;

  // Make these unpacked arrays and drive them element-wise
  prim_alert_pkg::alert_tx_t alert_test [NumAlerts-1:0];
  logic alerts [NumAlerts-1:0];

  // replicate alert_test and set alerts: element 0 driven by reg_intg_err,
  // other elements tied to 0 to avoid multiple structural drivers.
  genvar gi;
  for (gi = 0; gi < NumAlerts; gi = gi + 1) begin : ALERT_TEST_ASSIGN
    // replicate register test bit for each alert output
    assign alert_test[gi] = reg2hw.alert_test.q & reg2hw.alert_test.qe;

    // only element 0 is driven by the reg_top intg_err; others are tied low
    if (gi == 0) begin
      assign alerts[gi] = reg_intg_err;
    end else begin
      assign alerts[gi] = 1'b0;
    end
  end

  // instantiate reg top; connect its intg_err_o to reg_intg_err (single driver)
  pattgen_reg_top u_reg (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tl_i(tl_i),
    .tl_o(tl_o),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg),
    .intg_err_o(reg_intg_err)   // <- single driver for the reg integrity output
  );

  // instantiate alert senders
  genvar gidx;
  for (gidx = 0; gidx < NumAlerts; gidx = gidx + 1) begin : gen_alert_tx
    prim_alert_sender #(
      .AsyncOn(1'b1),
      .SkewCycles(1),
      .IsFatal(1'b1)
    ) u_prim_alert_sender (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .alert_test_i  ( alert_test[gidx] ),
      .alert_req_i   ( alerts[0]     ),
      .alert_ack_o   (               ),
      .alert_state_o (               ),
      .alert_rx_i    ( alert_rx_i[gidx] ),
      .alert_tx_o    ( alert_tx_o[gidx] )
    );
  end

  assign cio_pda0_tx_en_o = 1'b1;
  assign cio_pcl0_tx_en_o = 1'b1;
  assign cio_pda1_tx_en_o = 1'b1;
  assign cio_pcl1_tx_en_o = 1'b1;

  pattgen_core u_pattgen_core (
    .clk_i,
    .rst_ni,
    .reg2hw(reg2hw),
    .hw2reg(hw2reg),

    .pda0_tx_o(cio_pda0_tx_o),
    .pcl0_tx_o(cio_pcl0_tx_o),
    .pda1_tx_o(cio_pda1_tx_o),
    .pcl1_tx_o(cio_pcl1_tx_o),

    .intr_done_ch0_o(intr_done_ch0_o),
    .intr_done_ch1_o(intr_done_ch1_o)
  );

  `ASSERT_KNOWN(TlDValidKnownO_A, tl_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_o.a_ready)
  `ASSERT_KNOWN(AlertsKnown_A, alert_tx_o)
  `ASSERT_KNOWN(Pcl0TxKnownO_A, cio_pcl0_tx_o)
  `ASSERT_KNOWN(Pda0TxKnownO_A, cio_pda0_tx_o)
  `ASSERT_KNOWN(Pcl1TxKnownO_A, cio_pcl1_tx_o)
  `ASSERT_KNOWN(Pda1TxKnownO_A, cio_pda1_tx_o)
  `ASSERT_KNOWN(IntrCh0DoneKnownO_A, intr_done_ch0_o)
  `ASSERT_KNOWN(IntrCh1DoneKnownO_A, intr_done_ch1_o)

  `ASSERT(Pcl0TxEnIsOne_A, cio_pcl0_tx_en_o === 1'b1, clk_i, !rst_ni)
  `ASSERT(Pda0TxEnIsOne_A, cio_pda0_tx_en_o === 1'b1, clk_i, !rst_ni)
  `ASSERT(Pcl1TxEnIsOne_A, cio_pcl1_tx_en_o === 1'b1, clk_i, !rst_ni)
  `ASSERT(Pda1TxEnIsOne_A, cio_pda1_tx_en_o === 1'b1, clk_i, !rst_ni)

  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(RegWeOnehotCheck_A, u_reg, alert_tx_o[0])
endmodule : pattgen_top
// -----------------------------------------------------------------------------

