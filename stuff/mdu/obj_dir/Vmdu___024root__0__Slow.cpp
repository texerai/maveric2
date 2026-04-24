// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmdu.h for the primary calling header

#include "Vmdu__pch.h"

VL_ATTR_COLD void Vmdu___024root___eval_static(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_static\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__arst_i__0 = vlSelfRef.arst_i;
    vlSelfRef.__Vtrigprevexpr___TOP__clk_i__0 = vlSelfRef.clk_i;
}

VL_ATTR_COLD void Vmdu___024root___eval_initial(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_initial\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vmdu___024root___eval_final(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_final\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmdu___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vmdu___024root___eval_phase__stl(Vmdu___024root* vlSelf);

VL_ATTR_COLD void Vmdu___024root___eval_settle(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_settle\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vmdu___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("mdu.sv", 12, "", "DIDNOTCONVERGE: Settle region did not converge after '--converge-limit' of 10000 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        vlSelfRef.__VstlPhaseResult = Vmdu___024root___eval_phase__stl(vlSelf);
        vlSelfRef.__VstlFirstIteration = 0U;
    } while (vlSelfRef.__VstlPhaseResult);
}

VL_ATTR_COLD void Vmdu___024root___eval_triggers_vec__stl(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_triggers_vec__stl\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
}

VL_ATTR_COLD bool Vmdu___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmdu___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vmdu___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vmdu___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___trigger_anySet__stl\n"); );
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

VL_ATTR_COLD void Vmdu___024root___stl_sequent__TOP__0(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___stl_sequent__TOP__0\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0;
    mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0 = 0;
    VlWide<4>/*127:0*/ __Vtemp_1;
    VlWide<4>/*127:0*/ __Vtemp_2;
    VlWide<4>/*127:0*/ __Vtemp_3;
    VlWide<4>/*127:0*/ __Vtemp_4;
    VlWide<4>/*127:0*/ __Vtemp_5;
    // Body
    VL_SHIFTL_WWI(128,128,32, vlSelfRef.mdu__DOT__u_div__DOT__remainder_shifted, vlSelfRef.mdu__DOT__u_div__DOT__remainder, 1U);
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
    mdu__DOT__u_div__DOT____VdfgRegularize_hdefcd79e_0_0 
        = ((0U == (3U & (IData)(vlSelfRef.op))) | (2U 
                                                   == 
                                                   (3U 
                                                    & (IData)(vlSelfRef.op))));
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

VL_ATTR_COLD void Vmdu___024root___eval_stl(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_stl\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
        Vmdu___024root___stl_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD bool Vmdu___024root___eval_phase__stl(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___eval_phase__stl\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    Vmdu___024root___eval_triggers_vec__stl(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmdu___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vmdu___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        Vmdu___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

bool Vmdu___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmdu___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vmdu___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vmdu___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmdu___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vmdu___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge arst_i)\n");
    }
    if ((1U & (IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @(posedge clk_i)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vmdu___024root___ctor_var_reset(Vmdu___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmdu___024root___ctor_var_reset\n"); );
    Vmdu__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->clk_i = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11908517815223722933ull);
    vlSelf->arst_i = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14176615341084822543ull);
    vlSelf->start = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 9867861323841650631ull);
    vlSelf->op = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 3630531923276091163ull);
    vlSelf->is_mdu_word_op_i = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 9114925503669551577ull);
    vlSelf->A = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 3969090544990846983ull);
    vlSelf->B = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 149303876845869574ull);
    vlSelf->C = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 14230521632333904559ull);
    vlSelf->busy = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6386567572483775230ull);
    vlSelf->mdu__DOT__started_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 17473699365389820317ull);
    vlSelf->mdu__DOT__start_pulse = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 9937087594290556642ull);
    vlSelf->mdu__DOT__u_mul__DOT__multiplicand = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 15628163709209028406ull);
    vlSelf->mdu__DOT__u_mul__DOT__multiplier = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 10100497763189281487ull);
    VL_SCOPED_RAND_RESET_W(128, vlSelf->mdu__DOT__u_mul__DOT__accumulator, __VscopeHash, 7039357785626766210ull);
    vlSelf->mdu__DOT__u_mul__DOT__cycle_counter = VL_SCOPED_RAND_RESET_I(7, __VscopeHash, 12921510948768917560ull);
    vlSelf->mdu__DOT__u_mul__DOT__busy = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14165513150069377809ull);
    vlSelf->mdu__DOT__u_mul__DOT__op_stored = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 10462831040001087169ull);
    vlSelf->mdu__DOT__u_mul__DOT__a_sign = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8075989366424089790ull);
    vlSelf->mdu__DOT__u_mul__DOT__b_sign = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1801376345373570585ull);
    VL_SCOPED_RAND_RESET_W(128, vlSelf->mdu__DOT__u_mul__DOT__product_corrected, __VscopeHash, 12827990370235121486ull);
    VL_SCOPED_RAND_RESET_W(128, vlSelf->mdu__DOT__u_div__DOT__remainder, __VscopeHash, 167388322989045631ull);
    vlSelf->mdu__DOT__u_div__DOT__quotient = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 4096588541963911681ull);
    vlSelf->mdu__DOT__u_div__DOT__cycle_counter = VL_SCOPED_RAND_RESET_I(6, __VscopeHash, 17973506780713597516ull);
    vlSelf->mdu__DOT__u_div__DOT__busy = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1774329847278624727ull);
    vlSelf->mdu__DOT__u_div__DOT__op_stored = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 248864748575648845ull);
    vlSelf->mdu__DOT__u_div__DOT__dividend_negative_stored = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10950222010316336907ull);
    vlSelf->mdu__DOT__u_div__DOT__divisor_negative_stored = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10414530567778279580ull);
    vlSelf->mdu__DOT__u_div__DOT__quotient_negative_stored = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4204853309058017361ull);
    vlSelf->mdu__DOT__u_div__DOT__special_case_stored = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3748898194776714900ull);
    vlSelf->mdu__DOT__u_div__DOT__special_result_stored = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 4557340519681478582ull);
    vlSelf->mdu__DOT__u_div__DOT__start_dividend_negative = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11451466607589399321ull);
    vlSelf->mdu__DOT__u_div__DOT__start_divisor_negative = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14507791548044526864ull);
    VL_SCOPED_RAND_RESET_W(128, vlSelf->mdu__DOT__u_div__DOT__remainder_shifted, __VscopeHash, 3586413044181539873ull);
    VL_SCOPED_RAND_RESET_W(128, vlSelf->mdu__DOT__u_div__DOT__temp, __VscopeHash, 17384605118765400969ull);
    vlSelf->mdu__DOT__u_div__DOT__quotient_result = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 3416907072021735361ull);
    vlSelf->mdu__DOT__u_div__DOT__remainder_result = VL_SCOPED_RAND_RESET_Q(64, __VscopeHash, 8753392727360691403ull);
    vlSelf->__VdfgRegularize_h6e95ff9d_0_2 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__arst_i__0 = 0;
    vlSelf->__Vtrigprevexpr___TOP__clk_i__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
}
