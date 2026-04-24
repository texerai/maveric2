// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmdu.h for the primary calling header

#include "Vmdu__pch.h"

void Vmdu___024root___ctor_var_reset(Vmdu___024root* vlSelf);

Vmdu___024root::Vmdu___024root(Vmdu__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vmdu___024root___ctor_var_reset(this);
}

void Vmdu___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vmdu___024root::~Vmdu___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
