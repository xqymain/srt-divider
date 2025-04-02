# 2024年山东省电子设计大赛集成电路竞赛龙芯杯
**初赛题目：** 基于指定 FPGA 设计 32 位补码整数除法器，不得使用硬件描述语言的除号运算符或第三方 IP。前期备赛可自行利用 **vivado** 进行实验，最终 **FPGA** 实现与测试将由龙芯提供平台账号，于远程统一型号的 **FPGA** 测试平台中测试运行，预计 **8 月 12 日** 发放平台账号。运算累计特定数量的除法运算后，统计运算时间，并依据此进行排名。测试接口实例如下表所示。

| 信号         | 位宽 | 方向  | 功能                                               |
| ------------ | ---- | ----- | -------------------------------------------------- |
| div_clk      | 1    | input | 除法器模块时钟信号                                 |
| resetn       | 1    | input | 复位信号，低电平有效                               |
| div          | 1    | input | 除法运算命令，在除法完成后，如果外界没有新的除法进入，必须将该信号置为 0 |
| div_signed   | 1    | input | 控制有符号除法和无符号除法的信号                   |
| x            | 32   | input | 被除数                                             |
| y            | 32   | input | 除数                                               |
| s            | 32   | input | 除法结果，商                                       |
| r            | 32   | input | 除法结果，余数                                     |
| complete     | 1    | input | 除法完成信号，除法内部 count 计算达到 33           |

## 设计介绍
radix-16的SRT除法器，参考部分香山开源资料

**注：该题目来源于汪文祥、邢金璋所著《CPU设计实战》，该书章节5.2.3 电路级实现除法器包含基础设计、优化思路，并附除法器模块级验证Testbench。

-----------------------

# 2024 Shandong Province Electronic Design Contest - Integrated Circuit Competition (Loongson Cup)

**Preliminary Topic:** Design a 32-bit two's complement integer divider based on the specified FPGA. The division operation implemented must not use the division operator provided by hardware description languages or third-party IP cores. Participants may use **Vivado** software for preliminary preparations. The final FPGA implementation and testing will be conducted remotely on an FPGA test platform with unified specifications provided by Loongson. Platform accounts are expected to be distributed on **August 12**. Rankings will be based on the cumulative computation time required to complete a specified number of division operations. An example test interface is listed below:

| Signal      | Width | Direction | Function                                                                       |
|-------------|-------|-----------|--------------------------------------------------------------------------------|
| div_clk     | 1     | input     | Divider module clock signal                                                     |
| resetn      | 1     | input     | Reset signal, active low                                                        |
| div         | 1     | input     | Division command signal; must be set to 0 after division completes if no new division operation is pending |
| div_signed  | 1     | input     | Signal controlling signed or unsigned division                                  |
| x           | 32    | input     | Dividend                                                                        |
| y           | 32    | input     | Divisor                                                                         |
| s           | 32    | input     | Quotient (result of division)                                                   |
| r           | 32    | input     | Remainder (result of division)                                                  |
| complete    | 1     | input     | Division completion signal; asserted when internal count reaches 33             |

## Design Description
Radix-16 SRT divider, referencing portions of the XiangShan open-source resource.

**Note: This topic comes from the book "CPU Design Practice" written by Wang Wenxiang and Xing Jinzhang. Chapter 5.2.3 Circuit-level Implementation of Divider includes basic design, optimization ideas, and a divider module-level verification testbench.
