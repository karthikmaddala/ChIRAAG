`timescale 1ns/1ps
// design.sv -- integrated and fixed version (updated port / wire fixes)

`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV
`define ASSERT(name, expr, clk, rst) /* no-op */
`define ASSUME(name, expr, clk, rst) /* no-op */
`define ASSERT_KNOWN(name, sig) /* no-op */
`define ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(name, regmod, alert) /* no-op */
`endif

package adc_params;
  parameter int NumAlerts = 1;
  parameter int NumAdcChannel = 2;
  parameter int NumAdcFilter  = 4;
endpackage

package tlul_pkg;
  typedef struct packed {
    logic a_valid;
    logic d_valid;
    logic a_ready;
    logic d_ready;
    logic [31:0] a_data;
    logic [31:0] d_data;
  } tl_h2d_t;
  typedef struct packed {
    logic d_valid;
    logic a_ready;
    logic [31:0] d_data;
  } tl_d2h_t;
endpackage

package prim_alert_pkg;
  typedef logic alert_rx_t;
  typedef logic alert_tx_t;
endpackage

package ast_pkg;
  typedef struct packed {
    logic pd;
    logic [1:0] channel_sel;
  } adc_ast_req_t;
  typedef struct packed {
    logic [9:0] data;
    logic data_valid;
  } adc_ast_rsp_t;
endpackage

package adc_ctrl_pkg;
  typedef enum logic [4:0] {
    PWRDN, PWRUP,
    ONEST_0, ONEST_021, ONEST_1, ONEST_DONE,
    LP_0, LP_021, LP_1, LP_EVAL, LP_SLP, LP_PWRUP,
    NP_0, NP_021, NP_1, NP_EVAL, NP_DONE
  } fsm_state_e;
endpackage

package adc_ctrl_reg_pkg;
  import adc_params::*;
  typedef struct packed { logic q; logic qe; } reg_bit_t;
  typedef struct packed { logic [1:0] q; logic qe; } reg_2bit_t;
  typedef struct packed { logic [3:0] q; logic qe; } reg_4bit_t;
  typedef struct packed { logic [7:0] q; logic qe; } reg_8bit_t;
  typedef struct packed { logic [15:0] q; logic qe; } reg_16bit_t;
  typedef struct packed { logic [23:0] q; logic qe; } reg_24bit_t;
  typedef struct packed { logic [31:0] q; logic qe; } reg_32bit_t;

  typedef struct packed {
    reg_16bit_t min_v;
    reg_16bit_t max_v;
    reg_bit_t   cond;
    reg_bit_t   en;
  } filter_subreg_t;

  typedef struct packed {
    reg_16bit_t adc_chn_value;
    reg_16bit_t adc_chn_value_intr;
    reg_2bit_t  adc_chn_value_ext;
    reg_2bit_t  adc_chn_value_intr_ext;
  } adc_chn_val_mreg_t;

  typedef struct {
    struct {
      reg_bit_t adc_enable;
      reg_bit_t oneshot_mode;
    } adc_en_ctl;

    struct {
      reg_bit_t lp_mode;
      reg_4bit_t pwrup_time;
      reg_24bit_t wakeup_time;
    } adc_pd_ctl;

    reg_8bit_t adc_lp_sample_ctl;
    reg_16bit_t adc_sample_ctl;
    reg_bit_t adc_fsm_rst;

    filter_subreg_t adc_chn0_filter_ctl [NumAdcFilter];
    filter_subreg_t adc_chn1_filter_ctl [NumAdcFilter];

    struct {
      reg_8bit_t match_en;
      reg_bit_t  trans_en;
    } adc_wakeup_ctl;

    struct {
      reg_8bit_t match;
      reg_bit_t  trans;
    } filter_status;

    struct {
      reg_bit_t intr_enable;
      reg_bit_t intr_test;
      reg_bit_t alert_test;
    } intr_enable;
  } adc_ctrl_reg2hw_t;

  typedef struct {
    struct { reg_bit_t intr_state; } intr_state;
    adc_chn_val_mreg_t adc_chn_val [NumAdcChannel];
    struct {
      reg_8bit_t match;
      reg_bit_t  trans;
      reg_bit_t  oneshot;
    } adc_intr_status;
    struct {
      reg_8bit_t match;
      reg_bit_t  trans;
    } filter_status;
    struct { reg_4bit_t d; } adc_fsm_state;
  } adc_ctrl_hw2reg_t;
endpackage


module prim_pulse_sync (
  input  logic clk_src_i,
  input  logic rst_src_ni,
  input  logic src_pulse_i,
  input  logic clk_dst_i,
  input  logic rst_dst_ni,
  output logic dst_pulse_o
);
  logic src_ff;
  always_ff @(posedge clk_src_i or negedge rst_src_ni) begin
    if (!rst_src_ni) src_ff <= 1'b0;
    else src_ff <= src_pulse_i;
  end
  logic sync_reg;
  always_ff @(posedge clk_dst_i or negedge rst_dst_ni) begin
    if (!rst_dst_ni) sync_reg <= 1'b0;
    else sync_reg <= src_ff;
  end
  assign dst_pulse_o = sync_reg;
endmodule

module prim_alert_sender #(
  parameter logic AsyncOn = 1'b1,
  parameter int SkewCycles = 1,
  parameter bit IsFatal = 1'b1
)(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic alert_test_i,
  input  logic alert_req_i,
  output logic alert_ack_o,
  output logic [1:0] alert_state_o,
  input  logic alert_rx_i,
  output logic alert_tx_o
);
  assign alert_tx_o = alert_test_i | alert_req_i;
  assign alert_ack_o = 1'b0;
  assign alert_state_o = 2'b0;
endmodule

module adc_ctrl_reg_top (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic clk_aon_i,
  input  logic rst_aon_ni,
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,
  output adc_ctrl_reg_pkg::adc_ctrl_reg2hw_t reg2hw,
  input  adc_ctrl_reg_pkg::adc_ctrl_hw2reg_t hw2reg,
  output logic intg_err_o
);
  import adc_ctrl_reg_pkg::*;
  adc_ctrl_reg2hw_t reg2hw_reg;
  assign reg2hw = reg2hw_reg;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reg2hw_reg = '{default:'0};
      reg2hw_reg.adc_pd_ctl.pwrup_time.q = 4'h7;
      reg2hw_reg.adc_pd_ctl.wakeup_time.q = 24'h64;
      reg2hw_reg.adc_lp_sample_ctl.q = 8'h4;
      reg2hw_reg.adc_sample_ctl.q = 16'h9;
      reg2hw_reg.adc_en_ctl.adc_enable.q = 1'b1;
    end
  end

  assign tl_o = '{default:'0};
  assign intg_err_o = 1'b0;
endmodule

module adc_ctrl_fsm
  import adc_ctrl_reg_pkg::*;
  import adc_ctrl_pkg::*;
  import adc_params::*;
(
  input logic clk_aon_i,
  input logic rst_aon_ni,
  input logic cfg_fsm_rst_i,
  input logic cfg_adc_enable_i,
  input logic cfg_oneshot_mode_i,
  input logic cfg_lp_mode_i,
  input [3:0] cfg_pwrup_time_i,
  input [23:0] cfg_wakeup_time_i,
  input [7:0]  cfg_lp_sample_cnt_i,
  input [15:0] cfg_np_sample_cnt_i,
  input [NumAdcFilter-1:0] adc_ctrl_match_i,
  input [9:0] adc_d_i,
  input       adc_d_val_i,
  output logic      adc_pd_o,
  output logic[1:0] adc_chn_sel_o,
  output logic      chn0_val_we_o,
  output logic      chn1_val_we_o,
  output logic [9:0] chn0_val_o,
  output logic [9:0] chn1_val_o,
  output logic       adc_ctrl_done_o,
  output logic       oneshot_done_o,
  output adc_ctrl_pkg::fsm_state_e aon_fsm_state_o,
  output logic       aon_fsm_trans_o
);
  logic trigger_q;
  logic trigger_l2h, trigger_h2l;

  logic [3:0] pwrup_timer_cnt_d, pwrup_timer_cnt_q;
  logic pwrup_timer_cnt_clr, pwrup_timer_cnt_en;
  logic [9:0] chn0_val_d, chn1_val_d;
  logic fsm_chn0_sel, fsm_chn1_sel;
  logic chn0_val_we_d, chn1_val_we_d;
  logic [7:0] lp_sample_cnt_d, lp_sample_cnt_q;
  logic lp_sample_cnt_clr, lp_sample_cnt_en;
  logic [23:0] wakeup_timer_cnt_d, wakeup_timer_cnt_q;
  logic wakeup_timer_cnt_clr, wakeup_timer_cnt_en;
  logic [NumAdcFilter-1:0] adc_ctrl_match_q;
  logic stay_match;
  logic [15:0] np_sample_cnt_d, np_sample_cnt_q;
  logic np_sample_cnt_clr, np_sample_cnt_en;
  logic [7:0] lp_sample_cnt_thresh;
  logic [15:0] np_sample_cnt_thresh;

  adc_ctrl_pkg::fsm_state_e fsm_state_q, fsm_state_d;
  assign aon_fsm_state_o = fsm_state_q;

  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) trigger_q <= 1'b0;
    else if (cfg_fsm_rst_i) trigger_q <= 1'b0;
    else trigger_q <= cfg_adc_enable_i;
  end

  assign trigger_l2h = (trigger_q == 1'b0) && (cfg_adc_enable_i == 1'b1);
  assign trigger_h2l = (trigger_q == 1'b1) && (cfg_adc_enable_i == 1'b0);

  always_comb begin
    pwrup_timer_cnt_d = (pwrup_timer_cnt_en) ? pwrup_timer_cnt_q + 1'b1 : pwrup_timer_cnt_q;
    lp_sample_cnt_d    = (lp_sample_cnt_en) ? lp_sample_cnt_q + 1'b1 : lp_sample_cnt_q;
    np_sample_cnt_d    = (np_sample_cnt_en) ? np_sample_cnt_q + 1'b1 : np_sample_cnt_q;
    wakeup_timer_cnt_d = (wakeup_timer_cnt_en) ? wakeup_timer_cnt_q + 1'b1 : wakeup_timer_cnt_q;
  end

  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) begin
      pwrup_timer_cnt_q <= '0;
      lp_sample_cnt_q <= '0;
      np_sample_cnt_q <= '0;
      wakeup_timer_cnt_q <= '0;
    end else if (cfg_fsm_rst_i || trigger_h2l) begin
      pwrup_timer_cnt_q <= '0;
      lp_sample_cnt_q <= '0;
      np_sample_cnt_q <= '0;
      wakeup_timer_cnt_q <= '0;
    end else begin
      pwrup_timer_cnt_q <= pwrup_timer_cnt_d;
      lp_sample_cnt_q <= lp_sample_cnt_d;
      np_sample_cnt_q <= np_sample_cnt_d;
      wakeup_timer_cnt_q <= wakeup_timer_cnt_d;
    end
  end

  assign fsm_chn0_sel = (fsm_state_q == ONEST_0) || (fsm_state_q == LP_0) || (fsm_state_q == NP_0);
  assign chn0_val_we_d = fsm_chn0_sel && adc_d_val_i;
  assign chn0_val_d = (chn0_val_we_d) ? adc_d_i : chn0_val_o;

  assign fsm_chn1_sel = (fsm_state_q == ONEST_1) || (fsm_state_q == LP_1) || (fsm_state_q == NP_1);
  assign chn1_val_we_d = fsm_chn1_sel && adc_d_val_i;
  assign chn1_val_d = (chn1_val_we_d) ? adc_d_i : chn1_val_o;

  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) begin
      chn0_val_we_o <= '0; chn1_val_we_o <= '0;
      chn0_val_o <= '0; chn1_val_o <= '0;
    end else if (cfg_fsm_rst_i) begin
      chn0_val_we_o <= '0; chn1_val_we_o <= '0;
      chn0_val_o <= '0; chn1_val_o <= '0;
    end else begin
      chn0_val_we_o <= chn0_val_we_d;
      chn1_val_we_o <= chn1_val_we_d;
      chn0_val_o <= chn0_val_d;
      chn1_val_o <= chn1_val_d;
    end
  end

  logic ld_match;
  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) adc_ctrl_match_q <= '0;
    else if (cfg_fsm_rst_i) adc_ctrl_match_q <= '0;
    else if (ld_match) adc_ctrl_match_q <= adc_ctrl_match_i;
  end

  logic np_match;
  assign np_match = |adc_ctrl_match_i &
                    ((adc_ctrl_match_i == adc_ctrl_match_q) | ~|adc_ctrl_match_q);
  assign stay_match = np_match;

  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) fsm_state_q <= PWRDN;
    else if (trigger_h2l || cfg_fsm_rst_i) fsm_state_q <= PWRDN;
    else fsm_state_q <= fsm_state_d;
  end

  assign lp_sample_cnt_thresh = cfg_lp_sample_cnt_i - 1'b1;
  assign np_sample_cnt_thresh = cfg_np_sample_cnt_i - 1'b1;

  always_comb begin
    fsm_state_d = fsm_state_q;
    adc_chn_sel_o = 2'b0;
    adc_pd_o = 1'b0;
    pwrup_timer_cnt_clr = 1'b0; pwrup_timer_cnt_en = 1'b0;
    lp_sample_cnt_clr = 1'b0; lp_sample_cnt_en = 1'b0;
    wakeup_timer_cnt_clr = 1'b0; wakeup_timer_cnt_en = 1'b0;
    np_sample_cnt_clr = 1'b0; np_sample_cnt_en = 1'b0;
    adc_ctrl_done_o = 1'b0; oneshot_done_o = 1'b0;
    ld_match = 1'b0;
    aon_fsm_trans_o = 1'b0;

    unique case (fsm_state_q)
      PWRDN: begin
        adc_pd_o = 1'b1;
        if (trigger_l2h) fsm_state_d = PWRUP;
      end
      PWRUP: begin
        if (pwrup_timer_cnt_q != cfg_pwrup_time_i) pwrup_timer_cnt_en = 1'b1;
        else begin
          pwrup_timer_cnt_clr = 1'b1;
          if (cfg_oneshot_mode_i) fsm_state_d = ONEST_0;
          else if (cfg_lp_mode_i) fsm_state_d = LP_0;
          else fsm_state_d = NP_0;
        end
      end
      ONEST_0: begin
        adc_chn_sel_o = 2'b01;
        if (adc_d_val_i) fsm_state_d = ONEST_021;
      end
      ONEST_021: begin if (!adc_d_val_i) fsm_state_d = ONEST_1; end
      ONEST_1: begin
        adc_chn_sel_o = 2'b10;
        if (adc_d_val_i) fsm_state_d = ONEST_DONE;
      end
      ONEST_DONE: begin oneshot_done_o = 1'b1; fsm_state_d = PWRDN; end
      LP_0: begin
        adc_chn_sel_o = 2'b01;
        if (adc_d_val_i) fsm_state_d = LP_021;
      end
      LP_021: begin if (!adc_d_val_i) fsm_state_d = LP_1; end
      LP_1: begin
        adc_chn_sel_o = 2'b10;
        if (adc_d_val_i) fsm_state_d = LP_EVAL;
      end
      LP_EVAL: begin
        if (!adc_d_val_i) begin
          ld_match = 1'b1;
          if (!stay_match) begin
            fsm_state_d = LP_SLP; lp_sample_cnt_clr = 1'b1;
          end else if (lp_sample_cnt_q < lp_sample_cnt_thresh) begin
            fsm_state_d = LP_SLP; lp_sample_cnt_en = 1'b1;
          end else if (lp_sample_cnt_q == lp_sample_cnt_thresh) begin
            fsm_state_d = NP_0; lp_sample_cnt_clr = 1'b1; aon_fsm_trans_o = 1'b1;
          end
        end
      end
      LP_SLP: begin
        adc_pd_o = 1'b1;
        if (wakeup_timer_cnt_q != cfg_wakeup_time_i) wakeup_timer_cnt_en = 1'b1;
        else begin fsm_state_d = LP_PWRUP; wakeup_timer_cnt_clr = 1'b1; end
      end
      LP_PWRUP: begin
        if (pwrup_timer_cnt_q != cfg_pwrup_time_i) pwrup_timer_cnt_en = 1'b1;
        else begin pwrup_timer_cnt_clr = 1'b1; fsm_state_d = LP_0; end
      end
      NP_0: begin
        adc_chn_sel_o = 2'b01;
        if (adc_d_val_i) fsm_state_d = NP_021;
      end
      NP_021: begin if (!adc_d_val_i) fsm_state_d = NP_1; end
      NP_1: begin
        adc_chn_sel_o = 2'b10;
        if (adc_d_val_i) fsm_state_d = NP_EVAL;
      end
      NP_EVAL: begin
        if (!adc_d_val_i) begin
          ld_match = 1'b1;
          if (!stay_match) begin
            if (cfg_lp_mode_i) fsm_state_d = LP_0; else fsm_state_d = NP_0;
            np_sample_cnt_clr = 1'b1;
          end else if (np_sample_cnt_q < np_sample_cnt_thresh) begin
            fsm_state_d = NP_0; np_sample_cnt_en = 1'b1;
          end else if (np_sample_cnt_q == np_sample_cnt_thresh) begin
            fsm_state_d = NP_DONE; np_sample_cnt_en = 1'b1;
          end else if (np_sample_cnt_q > np_sample_cnt_thresh) begin
            fsm_state_d = NP_0;
          end
        end
      end
      NP_DONE: begin adc_ctrl_done_o = 1'b1; fsm_state_d = NP_0; end
      default: fsm_state_d = PWRDN;
    endcase
  end

  //
  // ======= SVA Assertions added here (inside adc_ctrl_fsm) =======
  //
  // Place these properties inside this module so all referenced signals are in scope.
  //

  // 1) ONESHOT: oneshot_done should be followed by chn1 write then chn0 write (one cycle apart)
  property p_oneshot_sequence;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      oneshot_done_o |-> (##1 chn1_val_we_o) ##1 chn0_val_we_o;
  endproperty
  assert property (p_oneshot_sequence)
    else $error("SVA: oneshot_done -> chn1_val_we then chn0_val_we (1 cycle gaps) failed");

  // 2) Trigger rising (trigger_l2h) should cause the FSM to enter PWRUP in next cycle
  property p_trigger_to_pwrup;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      trigger_l2h |-> ##1 (fsm_state_q == PWRUP);
  endproperty
  assert property (p_trigger_to_pwrup)
    else $error("SVA: trigger_l2h did not lead to PWRUP next cycle");

  // 3) Trigger falling (trigger_h2l) should cause FSM to go to PWRDN next cycle
  property p_trigger_to_pwrdn;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      trigger_h2l |-> ##1 (fsm_state_q == PWRDN);
  endproperty
  assert property (p_trigger_to_pwrdn)
    else $error("SVA: trigger_h2l did not lead to PWRDN next cycle");

  // 4) NP_DONE state asserts adc_ctrl_done_o in the same cycle and returns to NP_0 next cycle
  //    Write the consequent as a sequence: adc_ctrl_done_o ##1 fsm_state_q==NP_0
  property p_np_done_done_and_return;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      (fsm_state_q == NP_DONE) |-> (adc_ctrl_done_o) ##1 (fsm_state_q == NP_0);
  endproperty
  assert property (p_np_done_done_and_return)
    else $error("SVA: NP_DONE must assert adc_ctrl_done_o and then return to NP_0");

  // 5) LP_SLP state must have ADC powered down (adc_pd_o asserted) while in that state
  property p_lp_slp_powerdown;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      (fsm_state_q == LP_SLP) |-> (adc_pd_o == 1'b1);
  endproperty
  assert property (p_lp_slp_powerdown)
    else $error("SVA: LP_SLP must drive adc_pd_o = 1");

  // 6) When FSM is selecting channel0 and adc_d_val_i occurs, chn0_val_we_o should be asserted next cycle
  property p_chan0_sample_write;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      (fsm_chn0_sel && adc_d_val_i) |-> ##1 (chn0_val_we_o == 1'b1);
  endproperty
  assert property (p_chan0_sample_write)
    else $error("SVA: Sampling chn0 with adc_d_val_i should produce chn0_val_we_o next cycle");

  // 7) When ld_match occurs and there is no stay_match, np_sample_cnt_q must be cleared to zero
  property p_ld_match_clears_np_cnt;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      (ld_match && !stay_match) |-> (np_sample_cnt_q == '0);
  endproperty
  assert property (p_ld_match_clears_np_cnt)
    else $error("SVA: ld_match & !stay_match should clear np_sample_cnt_q");

  // 8) If in PWRUP state, the pwrup timer should be enabled while the counter hasn't reached cfg_pwrup_time_i
  property p_pwrup_timer_progress;
    @(posedge clk_aon_i)
      disable iff (!rst_aon_ni)
      (fsm_state_q == PWRUP && pwrup_timer_cnt_q != cfg_pwrup_time_i) |-> (pwrup_timer_cnt_en);
  endproperty
  assert property (p_pwrup_timer_progress)
    else $error("SVA: In PWRUP, timer should be enabled (pwrup_timer_cnt_en) while not at target");

  //
  // ======= End SVA block =======
  //

endmodule


module adc_ctrl_core
  import adc_ctrl_reg_pkg::*;
  import adc_ctrl_pkg::*;
  import adc_params::*;
(
  input  logic clk_aon_i,
  input  logic rst_aon_ni,
  input  logic clk_i,
  input  logic rst_ni,

  input  adc_ctrl_reg_pkg::adc_ctrl_reg2hw_t reg2hw_i,
  // expose FSM state as 4-bit vector to match hw2reg.adc_fsm_state.d.q (4 bits)
  output logic [3:0] aon_fsm_state_o,
  output adc_ctrl_reg_pkg::adc_ctrl_hw2reg_t adc_chn_val_o,
  output logic wkup_req_o,
  output logic intr_o,
  input  ast_pkg::adc_ast_rsp_t adc_i,
  output ast_pkg::adc_ast_req_t adc_o
);
  typedef struct packed {
    logic [9:0] min_v;
    logic [9:0] max_v;
    logic cond;
    logic en;
  } filter_ctl_t;

  filter_ctl_t aon_filter_ctl[NumAdcChannel][NumAdcFilter];

  genvar k;
  generate
    for (k = 0; k < NumAdcFilter; k++) begin : gen_filter_sync
      assign aon_filter_ctl[0][k].min_v = reg2hw_i.adc_chn0_filter_ctl[k].min_v.q[9:0];
      assign aon_filter_ctl[0][k].max_v = reg2hw_i.adc_chn0_filter_ctl[k].max_v.q[9:0];
      assign aon_filter_ctl[0][k].cond  = reg2hw_i.adc_chn0_filter_ctl[k].cond.q;
      assign aon_filter_ctl[0][k].en    = reg2hw_i.adc_chn0_filter_ctl[k].en.q;

      assign aon_filter_ctl[1][k].min_v = reg2hw_i.adc_chn1_filter_ctl[k].min_v.q[9:0];
      assign aon_filter_ctl[1][k].max_v = reg2hw_i.adc_chn1_filter_ctl[k].max_v.q[9:0];
      assign aon_filter_ctl[1][k].cond  = reg2hw_i.adc_chn1_filter_ctl[k].cond.q;
      assign aon_filter_ctl[1][k].en    = reg2hw_i.adc_chn1_filter_ctl[k].en.q;
    end
  endgenerate

  logic chn0_val_we, chn1_val_we;
  logic [9:0] chn0_val, chn1_val;
  logic [NumAdcFilter-1:0] match_pulse;
  logic [NumAdcFilter-1:0] match_vec;
  logic adc_pd_o;
  logic [1:0] adc_chn_sel_o;
  logic adc_ctrl_done, oneshot_done;
  logic aon_fsm_trans;

  // internal enum to connect to fsm
  adc_ctrl_pkg::fsm_state_e fsm_state_enum;

  adc_ctrl_fsm u_fsm (
    .clk_aon_i(clk_aon_i),
    .rst_aon_ni(rst_aon_ni),
    .cfg_fsm_rst_i(reg2hw_i.adc_fsm_rst.q),
    .cfg_adc_enable_i(reg2hw_i.adc_en_ctl.adc_enable.q),
    .cfg_oneshot_mode_i(reg2hw_i.adc_en_ctl.oneshot_mode.q),
    .cfg_lp_mode_i(reg2hw_i.adc_pd_ctl.lp_mode.q),
    .cfg_pwrup_time_i(reg2hw_i.adc_pd_ctl.pwrup_time.q),
    .cfg_wakeup_time_i(reg2hw_i.adc_pd_ctl.wakeup_time.q),
    .cfg_lp_sample_cnt_i(reg2hw_i.adc_lp_sample_ctl.q),
    .cfg_np_sample_cnt_i(reg2hw_i.adc_sample_ctl.q[15:0]),
    .adc_ctrl_match_i(match_vec),
    .adc_d_i(adc_i.data),
    .adc_d_val_i(adc_i.data_valid),
    .adc_pd_o(adc_pd_o),
    .adc_chn_sel_o(adc_chn_sel_o),
    .chn0_val_we_o(chn0_val_we),
    .chn1_val_we_o(chn1_val_we),
    .chn0_val_o(chn0_val),
    .chn1_val_o(chn1_val),
    .adc_ctrl_done_o(adc_ctrl_done),
    .oneshot_done_o(oneshot_done),
    .aon_fsm_state_o(fsm_state_enum),
    .aon_fsm_trans_o(aon_fsm_trans)
  );

  // drive outward 4-bit state as lower 4 bits of enum
  always_comb begin
    aon_fsm_state_o = fsm_state_enum[3:0];
  end

  genvar f;
  generate
    for (f = 0; f < NumAdcFilter; f++) begin : gen_match
      wire ch0_match = (!aon_filter_ctl[0][f].cond) ?
                       (aon_filter_ctl[0][f].min_v <= chn0_val && chn0_val <= aon_filter_ctl[0][f].max_v) :
                       (aon_filter_ctl[0][f].min_v > chn0_val || chn0_val > aon_filter_ctl[0][f].max_v);
      wire ch1_match = (!aon_filter_ctl[1][f].cond) ?
                       (aon_filter_ctl[1][f].min_v <= chn1_val && chn1_val <= aon_filter_ctl[1][f].max_v) :
                       (aon_filter_ctl[1][f].min_v > chn1_val || chn1_val > aon_filter_ctl[1][f].max_v);

      assign match_vec[f] = (aon_filter_ctl[0][f].en || aon_filter_ctl[1][f].en) &&
                            (!aon_filter_ctl[0][f].en || ch0_match) &&
                            (!aon_filter_ctl[1][f].en || ch1_match);

      assign match_pulse[f] = adc_ctrl_done && match_vec[f];
    end
  endgenerate

  adc_ctrl_reg_pkg::adc_ctrl_hw2reg_t hw2reg_stub;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hw2reg_stub = '{default:'0};
    end else begin
      if (chn0_val_we) hw2reg_stub.adc_chn_val[0].adc_chn_value.q = {6'b0, chn0_val};
      if (chn1_val_we) hw2reg_stub.adc_chn_val[1].adc_chn_value.q = {6'b0, chn1_val};
      hw2reg_stub.filter_status.match.q = |match_pulse;
      hw2reg_stub.adc_intr_status.match.q = |match_pulse;
      hw2reg_stub.adc_intr_status.oneshot.q = oneshot_done;
    end
  end

  assign adc_chn_val_o = hw2reg_stub;
  assign adc_o.pd = adc_pd_o;
  assign adc_o.channel_sel = adc_chn_sel_o;

  assign wkup_req_o = |(hw2reg_stub.filter_status.match.q & reg2hw_i.adc_wakeup_ctl.match_en.q);
  assign intr_o = |hw2reg_stub.adc_intr_status.match.q | hw2reg_stub.adc_intr_status.oneshot.q;
endmodule


module adc_ctrl
  import adc_ctrl_reg_pkg::*;
  import adc_params::*;
#(
  parameter logic [NumAlerts-1:0] AlertAsyncOn = {NumAlerts{1'b1}},
  parameter int unsigned AlertSkewCycles = 1
) (
  input  logic clk_i,
  input  logic clk_aon_i,
  input  logic rst_ni,
  input  logic rst_aon_ni,
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,
  input  prim_alert_pkg::alert_rx_t  alert_rx_i [NumAlerts],
  output prim_alert_pkg::alert_tx_t  alert_tx_o [NumAlerts],
  output ast_pkg::adc_ast_req_t adc_o,
  input  ast_pkg::adc_ast_rsp_t adc_i,
  output logic intr_match_pending_o,
  output logic wkup_req_o
);
  // make these nets so module outputs can drive them
  wire adc_ctrl_reg_pkg::adc_ctrl_reg2hw_t reg2hw;
  wire adc_ctrl_reg_pkg::adc_ctrl_hw2reg_t hw2reg;

  adc_ctrl_reg_top u_reg (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clk_aon_i(clk_aon_i),
    .rst_aon_ni(rst_aon_ni),
    .tl_i(tl_i),
    .tl_o(tl_o),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg),
    .intg_err_o()
  );

  // connect core; aon_fsm_state_o connects to hw2reg.adc_fsm_state.d.q (4 bits)
  adc_ctrl_core u_core (
    .clk_aon_i(clk_aon_i),
    .rst_aon_ni(rst_aon_ni),
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .reg2hw_i(reg2hw),
    .aon_fsm_state_o(hw2reg.adc_fsm_state.d.q),
    .adc_chn_val_o(hw2reg),
    .wkup_req_o(wkup_req_o),
    .intr_o(intr_match_pending_o),
    .adc_i(adc_i),
    .adc_o(adc_o)
  );

  genvar i;
  generate
    for (i=0; i<NumAlerts; i++) begin : alerts_gen
      prim_alert_sender #(
        .AsyncOn(AlertAsyncOn[i]),
        .SkewCycles(AlertSkewCycles),
        .IsFatal(1'b1)
      ) u_alert (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .alert_test_i(reg2hw.intr_enable.alert_test.q),
        .alert_req_i(1'b0),
        .alert_ack_o(),
        .alert_state_o(),
        .alert_rx_i(alert_rx_i[i]),
        .alert_tx_o(alert_tx_o[i])
      );
    end
  endgenerate

  `ASSERT_KNOWN(IntrKnown, intr_match_pending_o)
endmodule

