module top;

logic clock = 1;
logic resetN = 0;
import simplebus::*;
  
bus procmemif(clock,resetN);

always #5 clock = ~clock;

initial #2 resetN = 1;

ProcessorIntThread P(procmemif;);
MemoryIntThread M(procmemif;);

endmodule

package simplebus;
interface bus(input logic clock, resetN)
  tri dataValid, start, read;
  tri [7:0] data, address; 
endinterface
endpackage
