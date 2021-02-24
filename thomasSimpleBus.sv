module top;

logic clock=1, resetN=0;
tri dataValid, start, read;
tri [7:0] data address;

always #5 clock = ~clock;

initial #2 resetN=1;

ProcIntThread M(.*);
MemIntThread S(.*);
endmodule: top
