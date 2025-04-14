#include "Vdivider_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <random>
#include <ctime>
#include <cmath>
#include <limits>

#define MAX_TEST_CASES 1000
#define MAX_SIM_TIME 100000

std::mt19937 rng;
static int timeout_counter = 0;

void calc_expected_result(uint32_t x, uint32_t y, bool div_signed, int32_t& s_ref, int32_t& r_ref) {
    // Get absolute values of x and y
    bool x_signed = (x & 0x80000000) && div_signed;
    bool y_signed = (y & 0x80000000) && div_signed;
    
    uint32_t x_abs = x_signed ? (~x + 1) : x;
    uint32_t y_abs = y_signed ? (~y + 1) : y;
    
    bool s_ref_signed = (x_signed ^ y_signed) && div_signed;
    bool r_ref_signed = x_signed && div_signed;
    
    // absolute values
    uint32_t s_ref_abs = x_abs / y_abs;
    uint32_t r_ref_abs = x_abs - (s_ref_abs * y_abs);
    
    // Apply signs to reference
    s_ref = s_ref_signed ? (~s_ref_abs + 1) : s_ref_abs;
    r_ref = r_ref_signed ? (~r_ref_abs + 1) : r_ref_abs;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    // Instance
    Vdivider_top* top = new Vdivider_top;
    
    // Initialize VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("div_sim.vcd");
    
    // Initialize rng
    rng.seed(std::time(nullptr));
    std::uniform_int_distribution<uint32_t> rand_val(0, std::numeric_limits<uint32_t>::max());
    std::uniform_int_distribution<uint32_t> rand_bool(0, 1);
    
    int test_count = 0;
    int error_count = 0;
    uint64_t sim_time = 0;
    
    // signals
    top->div_clk = 0;
    top->resetn = 0;
    top->div_start = 0;              // Using renamed port
    top->division_signed = 0;        // Using renamed port
    top->dividend = 0;               // Using renamed port
    top->divisor = 1;                // Using renamed port
    
    // Reset
    for (int i = 0; i < 10; i++) {
        top->div_clk = !top->div_clk;
        top->eval();
        tfp->dump(sim_time++);
    }
    
    // De-assert reset
    top->resetn = 1;
    
    // simulation flow
    while ((test_count < MAX_TEST_CASES) && (sim_time < MAX_SIM_TIME)) {
        // Toggle clock
        top->div_clk = !top->div_clk;
        top->eval();
        tfp->dump(sim_time++);
        
        // positive clock edge
        if (top->div_clk) {
            if (!top->div_start || top->division_complete) {
                if (top->division_complete && top->div_start) {
                    // Verify
                    int32_t s_ref, r_ref;
                    calculate_expected_results(top->dividend, top->divisor, top->division_signed, s_ref, r_ref);
                    
                    bool s_ok = (s_ref == top->quotient);
                    bool r_ok = (r_ref == top->remainder);
                    
                    if (s_ok && r_ok) {
                        printf("[time=%lu]: x=%d, y=%d, signed=%d, s=%d, r=%d, s_OK=%d, r_OK=%d\n",
                               sim_time, top->division_signed ? (int32_t)top->dividend : top->dividend,
                               top->division_signed ? (int32_t)top->divisor : top->divisor,
                               top->division_signed, 
                               top->division_signed ? (int32_t)top->quotient : top->quotient,
                               top->division_signed ? (int32_t)top->remainder : top->remainder, 
                               s_ok, r_ok);
                        timeout_counter = 0;
                    } else {
                        printf("[time=%lu] ERROR: x=%d, y=%d, signed=%d, s=%d, r=%d, s_ref=%d, r_ref=%d, s_OK=%d, r_OK=%d\n",
                               sim_time, top->division_signed ? (int32_t)top->dividend : top->dividend,
                               top->division_signed ? (int32_t)top->divisor : top->divisor,
                               top->division_signed, 
                               top->division_signed ? (int32_t)top->quotient : top->quotient,
                               top->division_signed ? (int32_t)top->remainder : top->remainder,
                               top->division_signed ? (int32_t)s_ref : s_ref,
                               top->division_signed ? (int32_t)r_ref : r_ref, 
                               s_ok, r_ok);
                        error_count++;
                    }
                    
                    test_count++;
                }
                
                // Prepare next test case
                top->div_start = 0;
                int wait_clk = rand() % 4;
                for (int i = 0; i < wait_clk * 2; i++) {
                    top->div_clk = !top->div_clk;
                    top->eval();
                    tfp->dump(sim_time++);
                }
                
                top->division_signed = rand_bool(rng);
                
                // special cases
                if (test_count % 10 == 0) {
                    // Test edge cases periodically
                    switch(test_count % 50) {
                        case 0:  // Max positive / 1
                            top->dividend = 0x7FFFFFFF;
                            top->divisor = 1;
                            break;
                        case 10: // Min negative / -1 (overflow case)
                            top->dividend = 0x80000000;
                            top->divisor = 0xFFFFFFFF;  // -1 in two's complement
                            top->division_signed = 1;   // Must be signed
                            break;
                        case 20: // Max positive / max positive
                            top->dividend = 0x7FFFFFFF;
                            top->divisor = 0x7FFFFFFF;
                            break;
                        case 30: // Min negative / 2
                            top->dividend = 0x80000000;
                            top->divisor = 2;
                            top->division_signed = 1;
                            break;
                        case 40: // Division by small number
                            top->dividend = rand_val(rng);
                            top->divisor = (rand() % 10) + 1; // 1-10
                            break;
                        default:
                            top->dividend = rand_val(rng);
                            top->divisor = rand_val(rng);
                            // y is not zero
                            if (top->divisor == 0) top->divisor = 1;
                            break;
                    }
                } else {
                    // Random values
                    top->dividend = rand_val(rng);
                    top->divisor = rand_val(rng);
                    // y is not zero
                    if (top->divisor == 0) top->divisor = 1;
                }
                
                top->div_start = 1;
            }
            
            // timeout (34 clock cycles as in testbench)
            if (top->div_start && !top->division_complete) {
                timeout_counter++;
                if (timeout_counter > 34) {
                    printf("[time=%lu]Error: Division did not complete within 34 clock cycles! cycles:%d\n", sim_time, timeout_counter);
                    //break;
                }
            } else {
                timeout_counter = 0;
            }
        }
    }
    
    // Summary
    printf("\n==== Simulation Summary ====\n");
    printf("Total tests: %d\n", test_count);
    printf("Passed: %d\n", test_count - error_count);
    printf("Failed: %d\n", error_count);
    printf("Success rate: %.2f%%\n", (test_count > 0) ? ((test_count - error_count) * 100.0 / test_count) : 0.0);
    
    // Cleanup
    tfp->close();
    delete tfp;
    delete top;
    
    return (error_count > 0);
}
