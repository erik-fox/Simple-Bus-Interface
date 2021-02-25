package simplebus;
interface bus(input logic clock, resetN)
  tri dataValid, start, read;
  tri [7:0] data, address; 
endinterface
endpackage
