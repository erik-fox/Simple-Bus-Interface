ECE571 - HW 6 Simple bus interface: Processor with multiple memory modules possible /n
vlog simplebusif.sv /n
vsim -c -gN=(Number of desired memory modules) top /n
run -all
