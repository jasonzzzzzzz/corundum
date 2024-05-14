module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/dram_test_ch.fst");
    $dumpvars(0, dram_test_ch);
end
endmodule
