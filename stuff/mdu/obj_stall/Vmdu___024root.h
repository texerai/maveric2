// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vmdu.h for the primary calling header

#ifndef VERILATED_VMDU___024ROOT_H_
#define VERILATED_VMDU___024ROOT_H_  // guard

#include "verilated.h"


class Vmdu__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vmdu___024root final {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk_i,0,0);
    VL_IN8(arst_i,0,0);
    VL_IN8(start,0,0);
    VL_IN8(op,2,0);
    VL_IN8(is_mdu_word_op_i,0,0);
    VL_OUT8(busy,0,0);
    CData/*0:0*/ mdu__DOT__started_r;
    CData/*0:0*/ mdu__DOT__start_pulse;
    CData/*6:0*/ mdu__DOT__u_mul__DOT__cycle_counter;
    CData/*0:0*/ mdu__DOT__u_mul__DOT__busy;
    CData/*1:0*/ mdu__DOT__u_mul__DOT__op_stored;
    CData/*0:0*/ mdu__DOT__u_mul__DOT__a_sign;
    CData/*0:0*/ mdu__DOT__u_mul__DOT__b_sign;
    CData/*5:0*/ mdu__DOT__u_div__DOT__cycle_counter;
    CData/*0:0*/ mdu__DOT__u_div__DOT__busy;
    CData/*1:0*/ mdu__DOT__u_div__DOT__op_stored;
    CData/*0:0*/ mdu__DOT__u_div__DOT__dividend_negative_stored;
    CData/*0:0*/ mdu__DOT__u_div__DOT__divisor_negative_stored;
    CData/*0:0*/ mdu__DOT__u_div__DOT__quotient_negative_stored;
    CData/*0:0*/ mdu__DOT__u_div__DOT__special_case_stored;
    CData/*0:0*/ mdu__DOT__u_div__DOT__start_dividend_negative;
    CData/*0:0*/ mdu__DOT__u_div__DOT__start_divisor_negative;
    CData/*0:0*/ __VdfgRegularize_h6e95ff9d_0_2;
    CData/*0:0*/ __VstlFirstIteration;
    CData/*0:0*/ __VstlPhaseResult;
    CData/*0:0*/ __VicoFirstIteration;
    CData/*0:0*/ __VicoPhaseResult;
    CData/*0:0*/ __Vtrigprevexpr___TOP__arst_i__0;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk_i__0;
    CData/*0:0*/ __VactPhaseResult;
    CData/*0:0*/ __VnbaPhaseResult;
    VlWide<4>/*127:0*/ mdu__DOT__u_mul__DOT__accumulator;
    VlWide<4>/*127:0*/ mdu__DOT__u_mul__DOT__product_corrected;
    VlWide<4>/*127:0*/ mdu__DOT__u_div__DOT__remainder;
    VlWide<4>/*127:0*/ mdu__DOT__u_div__DOT__remainder_shifted;
    VlWide<4>/*127:0*/ mdu__DOT__u_div__DOT__temp;
    IData/*31:0*/ __VactIterCount;
    VL_IN64(A,63,0);
    VL_IN64(B,63,0);
    VL_OUT64(C,63,0);
    QData/*63:0*/ mdu__DOT__u_mul__DOT__multiplicand;
    QData/*63:0*/ mdu__DOT__u_mul__DOT__multiplier;
    QData/*63:0*/ mdu__DOT__u_div__DOT__quotient;
    QData/*63:0*/ mdu__DOT__u_div__DOT__special_result_stored;
    QData/*63:0*/ mdu__DOT__u_div__DOT__quotient_result;
    QData/*63:0*/ mdu__DOT__u_div__DOT__remainder_result;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vmdu__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vmdu___024root(Vmdu__Syms* symsp, const char* namep);
    ~Vmdu___024root();
    VL_UNCOPYABLE(Vmdu___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
