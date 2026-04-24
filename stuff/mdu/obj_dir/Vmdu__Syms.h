// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VMDU__SYMS_H_
#define VERILATED_VMDU__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vmdu.h"

// INCLUDE MODULE CLASSES
#include "Vmdu___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vmdu__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vmdu* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vmdu___024root                 TOP;

    // CONSTRUCTORS
    Vmdu__Syms(VerilatedContext* contextp, const char* namep, Vmdu* modelp);
    ~Vmdu__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard
