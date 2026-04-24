// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmdu.h for the primary calling header

#include "Vmdu__pch.h"

void Vmdu___024root___eval_triggers_vec__ico(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_triggers_vec__ico\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(vlSelfRef.__VicoFirstIteration)));
}

bool Vmdu___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vmdu___024root___ico_sequent__TOP__0(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___ico_sequent__TOP__0\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0;
    mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0 = 0;
    VlWide<4>/*127:0*/ __Vtemp_1;
    VlWide<4>/*127:0*/ __Vtemp_2;
    // Body
    VL_SHIFTL_WWI(128,128,32, __Vtemp_1, vlSelfRef.mdu__DOT__u_div__DOT__remainder, 1U);
    __Vtemp_2[0U] = 0U;
    __Vtemp_2[1U] = 0U;
    __Vtemp_2[2U] = (IData)(((IData)(vlSelfRef.mdu__DOT__u_div__DOT__divisor_negative_stored)
                              ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                  ? (QData)((IData)(
                                                    ((IData)(1U) 
                                                     + 
                                                     (~ (IData)(vlSelfRef.B)))))
                                  : (1ULL + (~ vlSelfRef.B)))
                              : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                  ? (QData)((IData)(vlSelfRef.B))
                                  : vlSelfRef.B)));
    __Vtemp_2[3U] = (IData)((((IData)(vlSelfRef.mdu__DOT__u_div__DOT__divisor_negative_stored)
                               ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                   ? (QData)((IData)(
                                                     ((IData)(1U) 
                                                      + 
                                                      (~ (IData)(vlSelfRef.B)))))
                                   : (1ULL + (~ vlSelfRef.B)))
                               : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                   ? (QData)((IData)(vlSelfRef.B))
                                   : vlSelfRef.B)) 
                             >> 0x00000020U));
    VL_SUB_W(4, vlSelfRef.mdu__DOT__u_div__DOT__temp, __Vtemp_1, __Vtemp_2);
    vlSelfRef.mdu__DOT__start_pulse = ((~ (IData)(vlSelfRef.mdu__DOT__started_r)) 
                                       & (IData)(vlSelfRef.start));
    if ((4U & (IData)(vlSelfRef.op))) {
        vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2 = vlSelfRef.mdu__DOT__u_div__DOT__busy;
        vlSelfRef.C = ((IData)(vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored)
                        ? vlSelfRef.mdu__DOT__u_div__DOT__special_result_stored
                        : ((2U & (IData)(vlSelfRef.mdu__DOT__u_div__DOT__op_stored))
                            ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                ? (((QData)((IData)(
                                                    (- (IData)(
                                                               (1U 
                                                                & (IData)(
                                                                          (vlSelfRef.mdu__DOT__u_div__DOT__remainder_result 
                                                                           >> 0x0000001fU))))))) 
                                    << 0x00000020U) 
                                   | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder_result)))
                                : vlSelfRef.mdu__DOT__u_div__DOT__remainder_result)
                            : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                ? (((QData)((IData)(
                                                    (- (IData)(
                                                               (1U 
                                                                & (IData)(
                                                                          (vlSelfRef.mdu__DOT__u_div__DOT__quotient_result 
                                                                           >> 0x0000001fU))))))) 
                                    << 0x00000020U) 
                                   | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__quotient_result)))
                                : vlSelfRef.mdu__DOT__u_div__DOT__quotient_result)));
    } else {
        vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2 = vlSelfRef.mdu__DOT__u_mul__DOT__busy;
        vlSelfRef.C = ((2U & (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__op_stored))
                        ? (((QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[3U])) 
                            << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[2U])))
                        : ((1U & (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__op_stored))
                            ? (((QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[3U])) 
                                << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[2U])))
                            : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                ? (((QData)((IData)(
                                                    (- (IData)(
                                                               (vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U] 
                                                                >> 0x0000001fU))))) 
                                    << 0x00000020U) 
                                   | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U])))
                                : (((QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[1U])) 
                                    << 0x00000020U) 
                                   | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U]))))));
    }
    mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0 
        = ((0U == (3U & (IData)(vlSelfRef.op))) | (2U 
                                                   == 
                                                   (3U 
                                                    & (IData)(vlSelfRef.op))));
    vlSelfRef.busy = ((IData)(vlSelfRef.mdu__DOT__start_pulse) 
                      | (IData)(vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2));
    vlSelfRef.mdu__DOT__u_div__DOT__start_dividend_negative 
        = (((IData)(vlSelfRef.is_mdu_word_op_i) ? (IData)(
                                                          (vlSelfRef.A 
                                                           >> 0x0000001fU))
             : (IData)((vlSelfRef.A >> 0x0000003fU))) 
           & (IData)(mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0));
    vlSelfRef.mdu__DOT__u_div__DOT__start_divisor_negative 
        = (((IData)(vlSelfRef.is_mdu_word_op_i) ? (IData)(
                                                          (vlSelfRef.B 
                                                           >> 0x0000001fU))
             : (IData)((vlSelfRef.B >> 0x0000003fU))) 
           & (IData)(mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0));
}

void Vmdu___024root___eval_ico(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_ico\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VicoTriggered[0U])) {
        Vmdu___024root___ico_sequent__TOP__0(vlSelf);
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmdu___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vmdu___024root___eval_phase__ico(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_phase__ico\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    Vmdu___024root___eval_triggers_vec__ico(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmdu___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    __VicoExecute = Vmdu___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        Vmdu___024root___eval_ico(vlSelf);
    }
    return (__VicoExecute);
}

void Vmdu___024root___eval_triggers_vec__act(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_triggers_vec__act\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                    ((((IData)(vlSelfRef.clk_i) 
                                                       & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__clk_i__0))) 
                                                      << 1U) 
                                                     | ((IData)(vlSelfRef.arst_i) 
                                                        & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__arst_i__0))))));
    vlSelfRef.__Vtrigprevexpr___TOP__arst_i__0 = vlSelfRef.arst_i;
    vlSelfRef.__Vtrigprevexpr___TOP__clk_i__0 = vlSelfRef.clk_i;
}

bool Vmdu___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vmdu___024root___nba_sequent__TOP__0(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___nba_sequent__TOP__0\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    QData/*63:0*/ __Vdly__mdu__DOT__u_mul__DOT__multiplicand;
    __Vdly__mdu__DOT__u_mul__DOT__multiplicand = 0;
    QData/*63:0*/ __Vdly__mdu__DOT__u_mul__DOT__multiplier;
    __Vdly__mdu__DOT__u_mul__DOT__multiplier = 0;
    VlWide<4>/*127:0*/ __Vdly__mdu__DOT__u_mul__DOT__accumulator;
    VL_ZERO_W(128, __Vdly__mdu__DOT__u_mul__DOT__accumulator);
    CData/*6:0*/ __Vdly__mdu__DOT__u_mul__DOT__cycle_counter;
    __Vdly__mdu__DOT__u_mul__DOT__cycle_counter = 0;
    CData/*0:0*/ __Vdly__mdu__DOT__u_mul__DOT__busy;
    __Vdly__mdu__DOT__u_mul__DOT__busy = 0;
    QData/*63:0*/ __Vdly__mdu__DOT__u_div__DOT__quotient;
    __Vdly__mdu__DOT__u_div__DOT__quotient = 0;
    CData/*5:0*/ __Vdly__mdu__DOT__u_div__DOT__cycle_counter;
    __Vdly__mdu__DOT__u_div__DOT__cycle_counter = 0;
    CData/*0:0*/ __Vdly__mdu__DOT__u_div__DOT__busy;
    __Vdly__mdu__DOT__u_div__DOT__busy = 0;
    VlWide<4>/*127:0*/ __Vtemp_1;
    VlWide<4>/*127:0*/ __Vtemp_2;
    VlWide<4>/*127:0*/ __Vtemp_3;
    VlWide<4>/*127:0*/ __Vtemp_4;
    VlWide<4>/*127:0*/ __Vtemp_5;
    VlWide<4>/*127:0*/ __Vtemp_7;
    VlWide<4>/*127:0*/ __Vtemp_8;
    // Body
    __Vdly__mdu__DOT__u_mul__DOT__multiplicand = vlSelfRef.mdu__DOT__u_mul__DOT__multiplicand;
    __Vdly__mdu__DOT__u_mul__DOT__multiplier = vlSelfRef.mdu__DOT__u_mul__DOT__multiplier;
    __Vdly__mdu__DOT__u_mul__DOT__cycle_counter = vlSelfRef.mdu__DOT__u_mul__DOT__cycle_counter;
    __Vdly__mdu__DOT__u_mul__DOT__busy = vlSelfRef.mdu__DOT__u_mul__DOT__busy;
    __Vdly__mdu__DOT__u_mul__DOT__accumulator[0U] = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[0U];
    __Vdly__mdu__DOT__u_mul__DOT__accumulator[1U] = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[1U];
    __Vdly__mdu__DOT__u_mul__DOT__accumulator[2U] = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[2U];
    __Vdly__mdu__DOT__u_mul__DOT__accumulator[3U] = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[3U];
    __Vdly__mdu__DOT__u_div__DOT__cycle_counter = vlSelfRef.mdu__DOT__u_div__DOT__cycle_counter;
    __Vdly__mdu__DOT__u_div__DOT__busy = vlSelfRef.mdu__DOT__u_div__DOT__busy;
    __Vdly__mdu__DOT__u_div__DOT__quotient = vlSelfRef.mdu__DOT__u_div__DOT__quotient;
    if (vlSelfRef.arst_i) {
        __Vdly__mdu__DOT__u_mul__DOT__multiplicand = 0ULL;
        __Vdly__mdu__DOT__u_mul__DOT__multiplier = 0ULL;
        __Vdly__mdu__DOT__u_mul__DOT__accumulator[0U] = 0U;
        __Vdly__mdu__DOT__u_mul__DOT__accumulator[1U] = 0U;
        __Vdly__mdu__DOT__u_mul__DOT__accumulator[2U] = 0U;
        __Vdly__mdu__DOT__u_mul__DOT__accumulator[3U] = 0U;
        __Vdly__mdu__DOT__u_mul__DOT__cycle_counter = 0U;
        __Vdly__mdu__DOT__u_mul__DOT__busy = 0U;
        vlSelfRef.mdu__DOT__u_mul__DOT__op_stored = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__remainder[0U] = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__remainder[1U] = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U] = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U] = 0U;
        __Vdly__mdu__DOT__u_div__DOT__quotient = 0ULL;
        __Vdly__mdu__DOT__u_div__DOT__cycle_counter = 0U;
        __Vdly__mdu__DOT__u_div__DOT__busy = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__op_stored = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__dividend_negative_stored = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__divisor_negative_stored = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__quotient_negative_stored = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored = 0U;
        vlSelfRef.mdu__DOT__u_div__DOT__special_result_stored = 0ULL;
    } else {
        if ((((~ ((IData)(vlSelfRef.op) >> 2U)) & (IData)(vlSelfRef.mdu__DOT__start_pulse)) 
             & (~ (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__busy)))) {
            __Vdly__mdu__DOT__u_mul__DOT__multiplicand 
                = (((IData)((vlSelfRef.A >> 0x0000003fU)) 
                    & ((1U == (3U & (IData)(vlSelfRef.op))) 
                       | (2U == (3U & (IData)(vlSelfRef.op)))))
                    ? (1ULL + (~ vlSelfRef.A)) : vlSelfRef.A);
            __Vdly__mdu__DOT__u_mul__DOT__multiplier 
                = (((1U == (3U & (IData)(vlSelfRef.op))) 
                    & (IData)((vlSelfRef.B >> 0x0000003fU)))
                    ? (1ULL + (~ vlSelfRef.B)) : vlSelfRef.B);
            __Vdly__mdu__DOT__u_mul__DOT__accumulator[0U] = 0U;
            __Vdly__mdu__DOT__u_mul__DOT__accumulator[1U] = 0U;
            __Vdly__mdu__DOT__u_mul__DOT__accumulator[2U] = 0U;
            __Vdly__mdu__DOT__u_mul__DOT__accumulator[3U] = 0U;
            __Vdly__mdu__DOT__u_mul__DOT__cycle_counter = 0U;
            vlSelfRef.mdu__DOT__u_mul__DOT__a_sign 
                = (((1U == (3U & (IData)(vlSelfRef.op))) 
                    | (2U == (3U & (IData)(vlSelfRef.op)))) 
                   & (IData)((vlSelfRef.A >> 0x3fU)));
            vlSelfRef.mdu__DOT__u_mul__DOT__b_sign 
                = ((1U == (3U & (IData)(vlSelfRef.op))) 
                   & (IData)((vlSelfRef.B >> 0x3fU)));
            vlSelfRef.mdu__DOT__u_mul__DOT__op_stored 
                = (3U & (IData)(vlSelfRef.op));
            __Vdly__mdu__DOT__u_mul__DOT__busy = 1U;
        } else if (vlSelfRef.mdu__DOT__u_mul__DOT__busy) {
            if ((1U & (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__multiplier))) {
                __Vtemp_1[0U] = (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__multiplicand);
                __Vtemp_1[1U] = (IData)((vlSelfRef.mdu__DOT__u_mul__DOT__multiplicand 
                                         >> 0x00000020U));
                __Vtemp_1[2U] = 0U;
                __Vtemp_1[3U] = 0U;
                VL_SHIFTL_WWI(128,128,7, __Vtemp_2, __Vtemp_1, (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__cycle_counter));
                VL_ADD_W(4, __Vdly__mdu__DOT__u_mul__DOT__accumulator, vlSelfRef.mdu__DOT__u_mul__DOT__accumulator, __Vtemp_2);
            }
            __Vdly__mdu__DOT__u_mul__DOT__multiplier 
                = VL_SHIFTR_QQI(64,64,32, vlSelfRef.mdu__DOT__u_mul__DOT__multiplier, 1U);
            __Vdly__mdu__DOT__u_mul__DOT__cycle_counter 
                = (0x0000007fU & ((IData)(1U) + (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__cycle_counter)));
            if ((0x3fU == (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__cycle_counter))) {
                __Vdly__mdu__DOT__u_mul__DOT__busy = 0U;
            }
        }
        if (((((IData)(vlSelfRef.op) >> 2U) & (IData)(vlSelfRef.mdu__DOT__start_pulse)) 
             & (~ (IData)(vlSelfRef.mdu__DOT__u_div__DOT__busy)))) {
            vlSelfRef.mdu__DOT__u_div__DOT__op_stored 
                = (3U & (IData)(vlSelfRef.op));
            if ((0ULL == vlSelfRef.B)) {
                vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored = 1U;
                vlSelfRef.mdu__DOT__u_div__DOT__special_result_stored 
                    = ((2U & (IData)(vlSelfRef.op))
                        ? vlSelfRef.A : 0xffffffffffffffffULL);
            } else if ((vlSelfRef.A == vlSelfRef.B)) {
                vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored = 1U;
                vlSelfRef.mdu__DOT__u_div__DOT__special_result_stored 
                    = ((2U & (IData)(vlSelfRef.op))
                        ? 0ULL : 1ULL);
            } else if ((((0U == (3U & (IData)(vlSelfRef.op))) 
                         & (0x8000000000000000ULL == vlSelfRef.A)) 
                        & (0xffffffffffffffffULL == vlSelfRef.B))) {
                vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored = 1U;
                vlSelfRef.mdu__DOT__u_div__DOT__special_result_stored 
                    = ((0U == (3U & (IData)(vlSelfRef.op)))
                        ? vlSelfRef.A : 0ULL);
            } else {
                vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored = 0U;
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[0U] 
                    = (IData)(((IData)(vlSelfRef.mdu__DOT__u_div__DOT__start_dividend_negative)
                                ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                    ? (QData)((IData)(
                                                      ((IData)(1U) 
                                                       + 
                                                       (~ (IData)(vlSelfRef.A)))))
                                    : (1ULL + (~ vlSelfRef.A)))
                                : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                    ? (QData)((IData)(vlSelfRef.A))
                                    : vlSelfRef.A)));
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[1U] 
                    = (IData)((((IData)(vlSelfRef.mdu__DOT__u_div__DOT__start_dividend_negative)
                                 ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                     ? (QData)((IData)(
                                                       ((IData)(1U) 
                                                        + 
                                                        (~ (IData)(vlSelfRef.A)))))
                                     : (1ULL + (~ vlSelfRef.A)))
                                 : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                     ? (QData)((IData)(vlSelfRef.A))
                                     : vlSelfRef.A)) 
                               >> 0x00000020U));
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U] = 0U;
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U] = 0U;
                __Vdly__mdu__DOT__u_div__DOT__quotient = 0ULL;
                __Vdly__mdu__DOT__u_div__DOT__cycle_counter = 0U;
                vlSelfRef.mdu__DOT__u_div__DOT__dividend_negative_stored 
                    = vlSelfRef.mdu__DOT__u_div__DOT__start_dividend_negative;
                vlSelfRef.mdu__DOT__u_div__DOT__divisor_negative_stored 
                    = vlSelfRef.mdu__DOT__u_div__DOT__start_divisor_negative;
                vlSelfRef.mdu__DOT__u_div__DOT__quotient_negative_stored 
                    = ((IData)(vlSelfRef.mdu__DOT__u_div__DOT__start_dividend_negative) 
                       ^ (IData)(vlSelfRef.mdu__DOT__u_div__DOT__start_divisor_negative));
                __Vdly__mdu__DOT__u_div__DOT__busy = 1U;
            }
        } else if (vlSelfRef.mdu__DOT__u_div__DOT__busy) {
            __Vdly__mdu__DOT__u_div__DOT__cycle_counter 
                = (0x0000003fU & ((IData)(1U) + (IData)(vlSelfRef.mdu__DOT__u_div__DOT__cycle_counter)));
            if ((vlSelfRef.mdu__DOT__u_div__DOT__temp[3U] 
                 >> 0x0000001fU)) {
                __Vdly__mdu__DOT__u_div__DOT__quotient 
                    = VL_SHIFTL_QQI(64,64,32, vlSelfRef.mdu__DOT__u_div__DOT__quotient, 1U);
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[0U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__remainder_shifted[0U];
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[1U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__remainder_shifted[1U];
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__remainder_shifted[2U];
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__remainder_shifted[3U];
            } else {
                __Vdly__mdu__DOT__u_div__DOT__quotient 
                    = (1ULL | (vlSelfRef.mdu__DOT__u_div__DOT__quotient 
                               << 1U));
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[0U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__temp[0U];
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[1U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__temp[1U];
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__temp[2U];
                vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U] 
                    = vlSelfRef.mdu__DOT__u_div__DOT__temp[3U];
            }
            if ((0x3fU == (IData)(vlSelfRef.mdu__DOT__u_div__DOT__cycle_counter))) {
                __Vdly__mdu__DOT__u_div__DOT__busy = 0U;
            }
        }
    }
    vlSelfRef.mdu__DOT__u_mul__DOT__multiplicand = __Vdly__mdu__DOT__u_mul__DOT__multiplicand;
    vlSelfRef.mdu__DOT__u_mul__DOT__multiplier = __Vdly__mdu__DOT__u_mul__DOT__multiplier;
    vlSelfRef.mdu__DOT__u_mul__DOT__cycle_counter = __Vdly__mdu__DOT__u_mul__DOT__cycle_counter;
    vlSelfRef.mdu__DOT__u_mul__DOT__busy = __Vdly__mdu__DOT__u_mul__DOT__busy;
    vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[0U] 
        = __Vdly__mdu__DOT__u_mul__DOT__accumulator[0U];
    vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[1U] 
        = __Vdly__mdu__DOT__u_mul__DOT__accumulator[1U];
    vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[2U] 
        = __Vdly__mdu__DOT__u_mul__DOT__accumulator[2U];
    vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[3U] 
        = __Vdly__mdu__DOT__u_mul__DOT__accumulator[3U];
    vlSelfRef.mdu__DOT__u_div__DOT__cycle_counter = __Vdly__mdu__DOT__u_div__DOT__cycle_counter;
    vlSelfRef.mdu__DOT__u_div__DOT__busy = __Vdly__mdu__DOT__u_div__DOT__busy;
    vlSelfRef.mdu__DOT__u_div__DOT__quotient = __Vdly__mdu__DOT__u_div__DOT__quotient;
    __Vtemp_3[0U] = 1U;
    __Vtemp_3[1U] = 0U;
    __Vtemp_3[2U] = 0U;
    __Vtemp_3[3U] = 0U;
    __Vtemp_4[0U] = (~ vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[0U]);
    __Vtemp_4[1U] = (~ vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[1U]);
    __Vtemp_4[2U] = (~ vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[2U]);
    __Vtemp_4[3U] = (~ vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[3U]);
    VL_ADD_W(4, __Vtemp_5, __Vtemp_3, __Vtemp_4);
    if (((1U == (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__op_stored))
          ? ((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__a_sign) 
             ^ (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__b_sign))
          : ((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__a_sign) 
             & (2U == (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__op_stored))))) {
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U] 
            = __Vtemp_5[0U];
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[1U] 
            = __Vtemp_5[1U];
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[2U] 
            = __Vtemp_5[2U];
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[3U] 
            = __Vtemp_5[3U];
    } else {
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U] 
            = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[0U];
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[1U] 
            = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[1U];
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[2U] 
            = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[2U];
        vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[3U] 
            = vlSelfRef.mdu__DOT__u_mul__DOT__accumulator[3U];
    }
    VL_SHIFTL_WWI(128,128,32, vlSelfRef.mdu__DOT__u_div__DOT__remainder_shifted, vlSelfRef.mdu__DOT__u_div__DOT__remainder, 1U);
    VL_SHIFTL_WWI(128,128,32, __Vtemp_7, vlSelfRef.mdu__DOT__u_div__DOT__remainder, 1U);
    __Vtemp_8[0U] = 0U;
    __Vtemp_8[1U] = 0U;
    __Vtemp_8[2U] = (IData)(((IData)(vlSelfRef.mdu__DOT__u_div__DOT__divisor_negative_stored)
                              ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                  ? (QData)((IData)(
                                                    ((IData)(1U) 
                                                     + 
                                                     (~ (IData)(vlSelfRef.B)))))
                                  : (1ULL + (~ vlSelfRef.B)))
                              : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                  ? (QData)((IData)(vlSelfRef.B))
                                  : vlSelfRef.B)));
    __Vtemp_8[3U] = (IData)((((IData)(vlSelfRef.mdu__DOT__u_div__DOT__divisor_negative_stored)
                               ? ((IData)(vlSelfRef.is_mdu_word_op_i)
                                   ? (QData)((IData)(
                                                     ((IData)(1U) 
                                                      + 
                                                      (~ (IData)(vlSelfRef.B)))))
                                   : (1ULL + (~ vlSelfRef.B)))
                               : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                   ? (QData)((IData)(vlSelfRef.B))
                                   : vlSelfRef.B)) 
                             >> 0x00000020U));
    VL_SUB_W(4, vlSelfRef.mdu__DOT__u_div__DOT__temp, __Vtemp_7, __Vtemp_8);
    vlSelfRef.mdu__DOT__u_div__DOT__remainder_result 
        = (((2U == (IData)(vlSelfRef.mdu__DOT__u_div__DOT__op_stored)) 
            & ((IData)(vlSelfRef.mdu__DOT__u_div__DOT__dividend_negative_stored) 
               & (0ULL != (((QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U])) 
                            << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U]))))))
            ? (1ULL + (~ (((QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U])) 
                           << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U])))))
            : (((QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder[3U])) 
                << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder[2U]))));
    vlSelfRef.mdu__DOT__u_div__DOT__quotient_result 
        = (((0U == (IData)(vlSelfRef.mdu__DOT__u_div__DOT__op_stored)) 
            & ((IData)(vlSelfRef.mdu__DOT__u_div__DOT__quotient_negative_stored) 
               & (0ULL != vlSelfRef.mdu__DOT__u_div__DOT__quotient)))
            ? (1ULL + (~ vlSelfRef.mdu__DOT__u_div__DOT__quotient))
            : vlSelfRef.mdu__DOT__u_div__DOT__quotient);
    vlSelfRef.C = ((4U & (IData)(vlSelfRef.op)) ? ((IData)(vlSelfRef.mdu__DOT__u_div__DOT__special_case_stored)
                                                    ? vlSelfRef.mdu__DOT__u_div__DOT__special_result_stored
                                                    : 
                                                   ((2U 
                                                     & (IData)(vlSelfRef.mdu__DOT__u_div__DOT__op_stored))
                                                     ? 
                                                    ((IData)(vlSelfRef.is_mdu_word_op_i)
                                                      ? 
                                                     (((QData)((IData)(
                                                                       (- (IData)(
                                                                                (1U 
                                                                                & (IData)(
                                                                                (vlSelfRef.mdu__DOT__u_div__DOT__remainder_result 
                                                                                >> 0x0000001fU))))))) 
                                                       << 0x00000020U) 
                                                      | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__remainder_result)))
                                                      : vlSelfRef.mdu__DOT__u_div__DOT__remainder_result)
                                                     : 
                                                    ((IData)(vlSelfRef.is_mdu_word_op_i)
                                                      ? 
                                                     (((QData)((IData)(
                                                                       (- (IData)(
                                                                                (1U 
                                                                                & (IData)(
                                                                                (vlSelfRef.mdu__DOT__u_div__DOT__quotient_result 
                                                                                >> 0x0000001fU))))))) 
                                                       << 0x00000020U) 
                                                      | (QData)((IData)(vlSelfRef.mdu__DOT__u_div__DOT__quotient_result)))
                                                      : vlSelfRef.mdu__DOT__u_div__DOT__quotient_result)))
                    : ((2U & (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__op_stored))
                        ? (((QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[3U])) 
                            << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[2U])))
                        : ((1U & (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__op_stored))
                            ? (((QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[3U])) 
                                << 0x00000020U) | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[2U])))
                            : ((IData)(vlSelfRef.is_mdu_word_op_i)
                                ? (((QData)((IData)(
                                                    (- (IData)(
                                                               (vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U] 
                                                                >> 0x0000001fU))))) 
                                    << 0x00000020U) 
                                   | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U])))
                                : (((QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[1U])) 
                                    << 0x00000020U) 
                                   | (QData)((IData)(vlSelfRef.mdu__DOT__u_mul__DOT__product_corrected[0U])))))));
}

void Vmdu___024root___nba_sequent__TOP__1(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___nba_sequent__TOP__1\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (vlSelfRef.arst_i) {
        vlSelfRef.mdu__DOT__started_r = 0U;
    } else if (vlSelfRef.mdu__DOT__start_pulse) {
        vlSelfRef.mdu__DOT__started_r = 1U;
    } else if ((1U & (~ (IData)(vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2)))) {
        vlSelfRef.mdu__DOT__started_r = 0U;
    }
    vlSelfRef.mdu__DOT__start_pulse = ((~ (IData)(vlSelfRef.mdu__DOT__started_r)) 
                                       & (IData)(vlSelfRef.start));
}

void Vmdu___024root___nba_sequent__TOP__2(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___nba_sequent__TOP__2\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2 = ((4U 
                                                 & (IData)(vlSelfRef.op))
                                                 ? (IData)(vlSelfRef.mdu__DOT__u_div__DOT__busy)
                                                 : (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__busy));
}

void Vmdu___024root___nba_comb__TOP__0(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___nba_comb__TOP__0\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.busy = ((IData)(vlSelfRef.mdu__DOT__start_pulse) 
                      | (IData)(vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2));
}

void Vmdu___024root___eval_nba(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_nba\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((2ULL & vlSelfRef.__VnbaTriggered[0U])) {
        Vmdu___024root___nba_sequent__TOP__0(vlSelf);
    }
    if ((3ULL & vlSelfRef.__VnbaTriggered[0U])) {
        if (vlSelfRef.arst_i) {
            vlSelfRef.mdu__DOT__started_r = 0U;
        } else if (vlSelfRef.mdu__DOT__start_pulse) {
            vlSelfRef.mdu__DOT__started_r = 1U;
        } else if ((1U & (~ (IData)(vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2)))) {
            vlSelfRef.mdu__DOT__started_r = 0U;
        }
        vlSelfRef.mdu__DOT__start_pulse = ((~ (IData)(vlSelfRef.mdu__DOT__started_r)) 
                                           & (IData)(vlSelfRef.start));
    }
    if ((2ULL & vlSelfRef.__VnbaTriggered[0U])) {
        vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2 = 
            ((4U & (IData)(vlSelfRef.op)) ? (IData)(vlSelfRef.mdu__DOT__u_div__DOT__busy)
              : (IData)(vlSelfRef.mdu__DOT__u_mul__DOT__busy));
    }
    if ((3ULL & vlSelfRef.__VnbaTriggered[0U])) {
        vlSelfRef.busy = ((IData)(vlSelfRef.mdu__DOT__start_pulse) 
                          | (IData)(vlSelfRef.__VdfgRegularize_h6e95ff9d_0_2));
    }
}

void Vmdu___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmdu___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vmdu___024root___eval_phase__act(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_phase__act\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vmdu___024root___eval_triggers_vec__act(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmdu___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vmdu___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    return (0U);
}

void Vmdu___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vmdu___024root___eval_phase__nba(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_phase__nba\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vmdu___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        Vmdu___024root___eval_nba(vlSelf);
        Vmdu___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

void Vmdu___024root___eval(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VicoIterCount = 0U;
    vlSelfRef.__VicoFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VicoIterCount)))) {
#ifdef VL_DEBUG
            Vmdu___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
            VL_FATAL_MT("mdu.sv", 12, "", "DIDNOTCONVERGE: Input combinational region did not converge after '--converge-limit' of 10000 tries");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
        vlSelfRef.__VicoPhaseResult = Vmdu___024root___eval_phase__ico(vlSelf);
        vlSelfRef.__VicoFirstIteration = 0U;
    } while (vlSelfRef.__VicoPhaseResult);
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vmdu___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("mdu.sv", 12, "", "DIDNOTCONVERGE: NBA region did not converge after '--converge-limit' of 10000 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00002710U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vmdu___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("mdu.sv", 12, "", "DIDNOTCONVERGE: Active region did not converge after '--converge-limit' of 10000 tries");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
            vlSelfRef.__VactPhaseResult = Vmdu___024root___eval_phase__act(vlSelf);
        } while (vlSelfRef.__VactPhaseResult);
        vlSelfRef.__VnbaPhaseResult = Vmdu___024root___eval_phase__nba(vlSelf);
    } while (vlSelfRef.__VnbaPhaseResult);
}

#ifdef VL_DEBUG
void Vmdu___024root___eval_debug_assertions(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_debug_assertions\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.clk_i & 0xfeU)))) {
        Verilated::overWidthError("clk_i");
    }
    if (VL_UNLIKELY(((vlSelfRef.arst_i & 0xfeU)))) {
        Verilated::overWidthError("arst_i");
    }
    if (VL_UNLIKELY(((vlSelfRef.start & 0xfeU)))) {
        Verilated::overWidthError("start");
    }
    if (VL_UNLIKELY(((vlSelfRef.op & 0xf8U)))) {
        Verilated::overWidthError("op");
    }
    if (VL_UNLIKELY(((vlSelfRef.is_mdu_word_op_i & 0xfeU)))) {
        Verilated::overWidthError("is_mdu_word_op_i");
    }
}
#endif  // VL_DEBUG
