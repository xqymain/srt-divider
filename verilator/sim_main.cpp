#include "Vdivider_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <iostream>
#include <chrono>
#include <vector>
#include <algorithm>
#include <string>
#include <cmath>
#include <iomanip>
#include <random>
#include <ctime>
#include <map>
#include <tuple>

// Testcase
struct TestMetrics {
    uint32_t x;
    uint32_t y;
    bool div_signed;
    int cycles;
    bool passed;
};

// Calculate the expected results
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

std::tuple<int32_t, int32_t, int> exec_div(Vdivider_top* top, VerilatedVcdC* tfp, uint64_t& sim_time, int max_cycles) {
    int cycle_count = 0;
    
    top->div_start = 1;
    
    // until completion or timeout
    while (!top->division_complete && cycle_count < max_cycles) {
        top->div_clk = !top->div_clk;
        top->eval();
        tfp->dump(sim_time++);
        
        if (top->div_clk) {
            cycle_count++;
        }
    }
    
    if (cycle_count >= max_cycles) {
        printf("ERROR: Division timed out after %d cycles (x=%08x, y=%08x, signed=%d)\n", 
            max_cycles, top->dividend, top->divisor, top->division_signed);
        return std::make_tuple(-1, -1, -1);
    }
    
    // settle cycle
    int32_t q = top->quotient;
    int32_t r = top->remainder;
    
    top->div_start = 0;
    
    // gap cycles
    for (int i = 0; i < 4; i++) {
        top->div_clk = !top->div_clk;
        top->eval();
        tfp->dump(sim_time++);
    }
    
    return std::make_tuple(q, r, cycle_count);
}

// Count leading zeros
int lzc(uint32_t x) {
    if (x == 0) return 32;
    
    int count = 0;
    if ((x & 0xFFFF0000) == 0) { count += 16; x <<= 16; }
    if ((x & 0xFF000000) == 0) { count += 8;  x <<= 8;  }
    if ((x & 0xF0000000) == 0) { count += 4;  x <<= 4;  }
    if ((x & 0xC0000000) == 0) { count += 2;  x <<= 2;  }
    if ((x & 0x80000000) == 0) { count += 1; }
    
    return count;
}

// Generate specific bit patterns
void gen_specific_test(std::vector<std::pair<uint32_t, uint32_t>>& patterns) {
    // Edge cases
    patterns.push_back({0x7FFFFFFF, 0x00000001});  // Max positive / 1
    patterns.push_back({0x80000000, 0x00000001});  // Min negative / 1
    patterns.push_back({0x80000000, 0xFFFFFFFF});  // Min negative / -1 (special overflow case)
    patterns.push_back({0x00000000, 0x00000001});  // Zero / 1
    patterns.push_back({0x00000001, 0x00000001});  // 1 / 1
    patterns.push_back({0xFFFFFFFF, 0xFFFFFFFF});  // -1 / -1 (signed) or max / max (unsigned)
    patterns.push_back({0x00010000, 0x00000001});  // Medium / 1
    patterns.push_back({0x00000001, 0x00010000});  // 1 / Medium
}

// Generate random test patterns
void gen_random_test(std::vector<TestMetrics>& metrics, int num_tests) {
    std::mt19937 rng(std::time(nullptr));
    std::uniform_int_distribution<uint32_t> rand_val(0, std::numeric_limits<uint32_t>::max());
    std::uniform_int_distribution<uint32_t> rand_bool(0, 1);
    
    // distributions for different types of values
    std::uniform_int_distribution<uint32_t> small_vals(1, 1000);               // Small values
    std::uniform_int_distribution<uint32_t> medium_vals(1000, 1000000);        // Medium values
    std::uniform_int_distribution<uint32_t> large_vals(1000000, 0xFFFFFFFF);   // Large values
    std::uniform_int_distribution<int> lz_dist(0, 31);                         // For leading zeros
    
    for (int i = 0; i < num_tests; i++) {
        TestMetrics metric;
        
        // Decide distribution
        int choice = i % 10;
        switch (choice) {
            case 0: // Random small value
                metric.x = small_vals(rng);
                break;
            case 1: // Random medium value
                metric.x = medium_vals(rng);
                break;
            case 2: // Random large value
                metric.x = large_vals(rng);
                break;
            case 3: // Value with specific number of leading zeros
                {
                    int lz = lz_dist(rng);
                    metric.x = rand_val(rng) >> lz;
                    if (metric.x == 0) metric.x = 1; // Avoid zero
                }
                break;
            case 4: // Power of 2
                metric.x = 1 << (rand() % 31);
                break;
            case 5: // One less than power of 2
                metric.x = (1 << (rand() % 31)) - 1;
                break;
            case 6: // One more than power of 2
                metric.x = (1 << (rand() % 31)) + 1;
                break;
            case 7: // Negative value (for signed tests)
                metric.x = 0x80000000 | rand_val(rng);
                break;
            case 8: // Alternate bit pattern
                metric.x = 0xAAAAAAAA;
                break;
            case 9: // Fully random
            default:
                metric.x = rand_val(rng);
                break;
        }
        
        // same strategy for divisor, but ensure it's not zero
        choice = (i + 3) % 10; // Offset to mix up combinations
        switch (choice) {
            case 0: // Random small value
                metric.y = small_vals(rng);
                break;
            case 1: // Random medium value
                metric.y = medium_vals(rng);
                break;
            case 2: // Random large value
                metric.y = large_vals(rng);
                break;
            case 3: // Value with specific number of leading zeros
                {
                    int lz = lz_dist(rng);
                    metric.y = rand_val(rng) >> lz;
                    if (metric.y == 0) metric.y = 1; // Avoid zero
                }
                break;
            case 4: // Power of 2
                metric.y = 1 << (rand() % 31);
                break;
            case 5: // One less than power of 2
                metric.y = (1 << (rand() % 31)) - 1;
                if (metric.y == 0) metric.y = 1; // Avoid zero
                break;
            case 6: // One more than power of 2
                metric.y = (1 << (rand() % 31)) + 1;
                break;
            case 7: // Negative value (for signed tests)
                metric.y = 0x80000000 | rand_val(rng);
                break;
            case 8: // Alternate bit pattern
                metric.y = 0x55555555;
                break;
            case 9: // Fully random
            default:
                metric.y = rand_val(rng);
                if (metric.y == 0) metric.y = 1; // Avoid zero
                break;
        }
        
        // random signed or unsigned division
        metric.div_signed = rand_bool(rng);
        
        // initial
        metric.cycles = 0;
        metric.passed = false;
        
        metrics.push_back(metric);
    }
}

void print_performance_report(const std::vector<TestMetrics>& metrics) {
    // calc statistics
    int total_cycles = 0;
    int min_cycles = INT_MAX;
    int max_cycles = 0;
    int failed_count = 0;
    
    // Maps to track average cycles based on dividend and divisor characteristics
    std::map<int, std::pair<int, int>> div_lz_cycles;     // Leading zeros -> {total cycles, count}
    std::map<int, std::pair<int, int>> divisor_lz_cycles; // Leading zeros -> {total cycles, count}
    std::map<bool, std::pair<int, int>> signed_cycles;    // Signed -> {total cycles, count}
    
    for (const auto& metric : metrics) {
        if (metric.cycles > 0) {  // failed test, skip
            total_cycles += metric.cycles;
            min_cycles = std::min(min_cycles, metric.cycles);
            max_cycles = std::max(max_cycles, metric.cycles);
            
            // Track based on characteristics
            int div_lz = lzc(metric.x);
            int divisor_lz = lzc(metric.y);
            
            div_lz_cycles[div_lz].first += metric.cycles;
            div_lz_cycles[div_lz].second++;
            
            divisor_lz_cycles[divisor_lz].first += metric.cycles;
            divisor_lz_cycles[divisor_lz].second++;
            
            signed_cycles[metric.div_signed].first += metric.cycles;
            signed_cycles[metric.div_signed].second++;
        }
        if (!metric.passed) {
            failed_count++;
        }
    }
    
    double avg_cycles = 0;
    if (metrics.size() > failed_count) {
        avg_cycles = static_cast<double>(total_cycles) / (metrics.size() - failed_count);
    }
    
    // summary
    std::cout << "\n=== Performance Report ===\n";
    std::cout << "Total test cases: " << metrics.size() << "\n";
    std::cout << "Failed cases: " << failed_count << "\n";
    std::cout << "Minimum cycles: " << min_cycles << "\n";
    std::cout << "Maximum cycles: " << max_cycles << "\n";
    std::cout << "Average cycles: " << std::fixed << std::setprecision(2) << avg_cycles << "\n\n";
    
    // performance
    std::cout << "=== Performance by Dividend Leading Zeros ===\n";
    std::cout << "LZ\tAvg Cycles\tCount\n";
    for (int i = 0; i <= 32; i++) {
        if (div_lz_cycles.count(i) && div_lz_cycles[i].second > 0) {
            double avg = static_cast<double>(div_lz_cycles[i].first) / div_lz_cycles[i].second;
            std::cout << i << "\t" << std::fixed << std::setprecision(2) << avg 
                    << "\t\t" << div_lz_cycles[i].second << "\n";
        }
    }
    
    std::cout << "\n=== Performance by Divisor Leading Zeros ===\n";
    std::cout << "LZ\tAvg Cycles\tCount\n";
    for (int i = 0; i <= 32; i++) {
        if (divisor_lz_cycles.count(i) && divisor_lz_cycles[i].second > 0) {
            double avg = static_cast<double>(divisor_lz_cycles[i].first) / divisor_lz_cycles[i].second;
            std::cout << i << "\t" << std::fixed << std::setprecision(2) << avg 
                    << "\t\t" << divisor_lz_cycles[i].second << "\n";
        }
    }
    
    std::cout << "\n=== Performance by Signed/Unsigned ===\n";
    for (const auto& pair : signed_cycles) {
        if (pair.second.second > 0) {
            double avg = static_cast<double>(pair.second.first) / pair.second.second;
            std::cout << (pair.first ? "Signed" : "Unsigned") << ":\t" 
                    << std::fixed << std::setprecision(2) << avg << " cycles (avg), "
                    << pair.second.second << " tests\n";
        }
    }
    
    // detailed report header
    std::cout << "\n=== Detailed Performance Report ===\n";
    std::cout << std::setw(10) << "Dividend" << " | " 
            << std::setw(10) << "Divisor" << " | "
            << std::setw(6) << "Signed" << " | "
            << std::setw(7) << "Cycles" << " | "
            << "Result" << "\n";
    std::cout << std::string(50, '-') << "\n";
    
    // Print each test case
    for (const auto& metric : metrics) {
        std::cout << "0x" << std::hex << std::setw(8) << std::setfill('0') << metric.x << " | "
                << "0x" << std::hex << std::setw(8) << std::setfill('0') << metric.y << " | "
                << std::dec << std::setw(6) << std::setfill(' ') << (metric.div_signed ? "true" : "false") << " | "
                << std::setw(7) << (metric.cycles > 0 ? std::to_string(metric.cycles) : "FAILED") << " | "
                << (metric.passed ? "PASS" : "FAIL") << "\n";
    }
}

int main(int argc, char** argv) {
    // Parse command line arguments
    int num_tests = 500; // Default
    if (argc > 1) {
        num_tests = std::max(10, std::min(10000, atoi(argv[1])));
    }
    
    Verilated::commandArgs(argc, argv);
    
    // Instance
    Vdivider_top* top = new Vdivider_top;
    
    // Initialize VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("div_perf_test.vcd");
    
    uint64_t sim_time = 0;
    std::vector<TestMetrics> metrics;
    
    // Initialize signals
    top->div_clk = 0;
    top->resetn = 0;
    top->div_start = 0;
    top->division_signed = 0;
    top->dividend = 0;
    top->divisor = 1;
    
    // Reset sequence
    for (int i = 0; i < 10; i++) {
        top->div_clk = !top->div_clk;
        top->eval();
        tfp->dump(sim_time++);
    }
    
    // De-assert reset
    top->resetn = 1;
    
    // Wait cycles
    for (int i = 0; i < 4; i++) {
        top->div_clk = !top->div_clk;
        top->eval();
        tfp->dump(sim_time++);
    }
    
    // Generate random patterns
    printf("Generating %d random test patterns...\n", num_tests);
    gen_random_test(metrics, num_tests);
    
    // Add specific test patterns
    std::vector<std::pair<uint32_t, uint32_t>> specific_patterns;
    gen_specific_test(specific_patterns);
    
    for (const auto& pattern : specific_patterns) {
        for (bool is_signed : {false, true}) {
            TestMetrics metric;
            metric.x = pattern.first;
            metric.y = pattern.second;
            metric.div_signed = is_signed;
            metric.cycles = 0;
            metric.passed = false;
            metrics.push_back(metric);
        }
    }
    
    printf("Running %zu test cases...\n", metrics.size());
    
    // Run all the tests
    int test_count = 0;
    for (auto& metric : metrics) {
        // Show progress every 50 tests
        if (test_count % 50 == 0) {
            printf("Running test %d/%zu...\n", test_count, metrics.size());
        }
        test_count++;
        
        // inputs
        top->dividend = metric.x;
        top->divisor = metric.y;
        top->division_signed = metric.div_signed;

        // Execute and measure
        auto [q, r, c] = exec_div(top, tfp, sim_time, 50);
        metric.cycles = c;
        // Verify
        int32_t expected_q, expected_r;
        calc_expected_result(metric.x, metric.y, metric.div_signed, expected_q, expected_r);
        metric.passed = ((q == expected_q) && (r == expected_r));
        
        if (!metric.passed) {
            printf("Test failed: x=0x%08x, y=0x%08x, signed=%d\n", 
                metric.x, metric.y, metric.div_signed);
            printf("  Expected: q=0x%08x, r=0x%08x\n", (uint32_t)expected_q, (uint32_t)expected_r);
            printf("  Got:      q=0x%08x, r=0x%08x\n", top->quotient, top->remainder);
            
            // Print signed values for signed operations
            if (metric.div_signed) {
                printf("  As signed: Expected q=%d, r=%d\n", expected_q, expected_r);
                printf("  As signed: Got      q=%d, r=%d\n", (int32_t)top->quotient, (int32_t)top->remainder);
            }
        }
    }
    
    print_performance_report(metrics);
    
    // Cleanup
    tfp->close();
    delete tfp;
    delete top;
    
    return 0;
}
