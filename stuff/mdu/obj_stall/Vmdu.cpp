// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vmdu__pch.h"

//============================================================
// Constructors

Vmdu::Vmdu(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vmdu__Syms(contextp(), _vcname__, this)}
    , clk_i{vlSymsp->TOP.clk_i}
    , arst_i{vlSymsp->TOP.arst_i}
    , start{vlSymsp->TOP.start}
    , op{vlSymsp->TOP.op}
    , is_mdu_word_op_i{vlSymsp->TOP.is_mdu_word_op_i}
    , busy{vlSymsp->TOP.busy}
    , A{vlSymsp->TOP.A}
    , B{vlSymsp->TOP.B}
    , C{vlSymsp->TOP.C}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vmdu::Vmdu(const char* _vcname__)
    : Vmdu(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vmdu::~Vmdu() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vmdu___024root___eval_debug_assertions(Vmdu___024root* vlSelf);
#endif  // VL_DEBUG
void Vmdu___024root___eval_static(Vmdu___024root* vlSelf);
void Vmdu___024root___eval_initial(Vmdu___024root* vlSelf);
void Vmdu___024root___eval_settle(Vmdu___024root* vlSelf);
void Vmdu___024root___eval(Vmdu___024root* vlSelf);

void Vmdu::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vmdu::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vmdu___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vmdu___024root___eval_static(&(vlSymsp->TOP));
        Vmdu___024root___eval_initial(&(vlSymsp->TOP));
        Vmdu___024root___eval_settle(&(vlSymsp->TOP));
        vlSymsp->__Vm_didInit = true;
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vmdu___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vmdu::eventsPending() { return false; }

uint64_t Vmdu::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vmdu::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vmdu___024root___eval_final(Vmdu___024root* vlSelf);

VL_ATTR_COLD void Vmdu::final() {
    contextp()->executingFinal(true);
    Vmdu___024root___eval_final(&(vlSymsp->TOP));
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vmdu::hierName() const { return vlSymsp->name(); }
const char* Vmdu::modelName() const { return "Vmdu"; }
unsigned Vmdu::threads() const { return 1; }
void Vmdu::prepareClone() const { contextp()->prepareClone(); }
void Vmdu::atClone() const {
    contextp()->threadPoolpOnClone();
}
