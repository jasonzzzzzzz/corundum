module iverilog_dump();
initial begin
    $dumpfile("dram_test_ch.fst");
    $dumpvars(0, dram_test_ch);
end
endmodule
