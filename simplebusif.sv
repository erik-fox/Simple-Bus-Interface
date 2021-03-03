interface simplebus (input logic clock, resetN);
  tri dataValid;
  logic start;
  logic read;
  tri [7:0] data;
  logic [7:0] address; 
 
  modport leader (input resetN, 
                  input clock, 
                  output start, 
                  output read,
                  inout dataValid,
                  output  address,
                  inout  data);
  modport follower (input resetN, 
                    input clock,
                    input start,
                    input read,
                    inout dataValid,
                    input address,
                    inout data);
endinterface
  
module top;
parameter logic [7:0] N=1;
logic clock = 1;
logic resetN = 0;
  
simplebus procmemif(clock,resetN);

always #5 clock = ~clock;

initial
 begin
   $dumpfile("dump.vcd"); $dumpvars;
	$monitor("procmemif.dataValid = %h, procmemif.start = %h, procmemif.read = %h,procmemif.data = %h, procmemif.address = %h",procmemif.dataValid, procmemif.start, procmemif.read,procmemif.data, procmemif.address);
 #2 resetN = 1;
end
  ProcessorIntThread P(procmemif.leader);
genvar i;
generate
 for(i=0; i<N; i++)
	MemoryIntThread #(i) M(procmemif.follower);
endgenerate
endmodule


module ProcessorIntThread(simplebus bus);

logic en_AddrUp, en_AddrMid, en_AddrLo, ld_Data, en_Data, access = 0;
logic doRead, wDataRdy, dv;
logic [7:0] DataReg;
logic [23:0] AddrReg;

enum {ONE,TWO,THREE,FOUR,FIVE} State, NextState;

assign bus.data = (en_Data) ? DataReg : 'bz;
assign bus.dataValid = (State == FIVE) ? dv : 1'bz;

always_comb
    if (en_AddrLo) bus.address = AddrReg[7:0];
    else if (en_AddrMid) bus.address = AddrReg[15:8];
    else if (en_AddrUp) bus.address = AddrReg[23:16];
    else bus.address = 'bz;
    
always_ff @(posedge bus.clock)
    if (ld_Data) DataReg <= bus.data;
    
always_ff @(posedge bus.clock, negedge bus.resetN)
    if (!bus.resetN) State <= ONE;
    else State <= NextState;
    
    
always_comb
    begin
    bus.start = 0;
    en_AddrUp = 0;
    en_AddrMid = 0;
    en_AddrLo = 0;
    bus.read = 0;
    ld_Data = 0;
    en_Data = 0;
    dv = 0;
    
    case(State)
    ONE:begin
    	
	NextState = (access) ? TWO : ONE;
    	bus.start = (access) ? 1 : 0;
    	en_AddrUp = (access) ? 1 : 0;
    	end
    TWO:begin
	NextState=THREE;
    	en_AddrMid = 1 ;
	end
    THREE:begin
    	NextState = (doRead) ? FOUR : FIVE ;
    	en_AddrLo = 1;
    	bus.read = (doRead) ? 1 : 0;
    	end
    FOUR:begin
    	NextState = (bus.dataValid) ? ONE : FOUR;
    	ld_Data = (bus.dataValid) ? 1 : 0;
    	end
    FIVE:begin
    	NextState = (wDataRdy) ? ONE: FIVE;
    	en_Data = (wDataRdy) ? 1 : 0;
    	dv = (wDataRdy) ? 1 : 0;
    	end
    endcase
    end

task WriteMem(input [23:0] Avalue, input [7:0] Dvalue);   
begin
access <= 1;
doRead <= 0;
wDataRdy <= 1;
AddrReg <= Avalue;
DataReg <= Dvalue;
@(posedge bus.clock) access <= 0;
@(posedge bus.clock);
wait (State == ONE); 
repeat (2) @(posedge bus.clock);
end
endtask


task ReadMem(input [23:0] Avalue);   
begin
access <= 1;
doRead <= 1;
wDataRdy <= 0;
AddrReg <= Avalue;
  @(posedge bus.clock) access <= 0;
  @(posedge bus.clock);
wait (State == ONE); 
  repeat (2) @(posedge bus.clock);
end
endtask


initial
begin
repeat (2) @(posedge bus.clock);
// Note this is from the textbook but is *not* a good test!!
WriteMem(24'h010406, 8'hDC);
WriteMem(24'h020407, 8'hAB);
ReadMem(24'h010406);
ReadMem(24'h020407);
WriteMem(24'h020406, 8'hF1);
ReadMem(24'h020406);
$finish;
end
    

endmodule





module MemoryIntThread#(parameter N=0)(simplebus bus);
    
logic [7:0] Mem[16'hFFFF:0], MemData;
logic ld_AddrUp, ld_AddrLo,ld_AddrMid, memDataAvail = 0;
logic en_Data, ld_Data, dv;
logic [7:0] DataReg;
logic [23:0] AddrReg;

enum {ONE, TWO, THREE, FOUR,FIVE} State, NextState;


initial
    begin
    for (int i = 0; i < 16'hFFFF; i++)
        Mem[i] <= N;
    end

    
assign bus.data = (en_Data) ? MemData : 'bz;
assign bus.dataValid = (State == FOUR) ? dv : 1'bz;


always @(AddrReg, ld_Data)
	MemData = Mem[AddrReg[15:0]];
    
always_ff @(posedge bus.clock)
    if (ld_AddrUp) AddrReg[23:16] <= bus.address;
always_ff @(posedge bus.clock)
    if (ld_AddrMid) AddrReg[15:8] <= bus.address;
    
always_ff @(posedge bus.clock)
  if (ld_AddrLo) AddrReg[7:0] <= bus.address;

always @(posedge bus.clock)
    begin
    if (ld_Data)
        begin
        DataReg <= bus.data;
		Mem[AddrReg[15:0]] <= bus.data;
        end
    end
    
always_ff @(posedge bus.clock, negedge bus.resetN)
  if (!bus.resetN) State <= ONE;
  else State <= NextState;
  
always_comb
    begin
    ld_AddrUp = 0;
    ld_AddrMid = 0;
    ld_AddrLo = 0;
    dv = 0;
    en_Data = 0;
    ld_Data = 0;
    
    case (State)
    ONE: begin
        NextState = (bus.start) ? TWO : ONE;
        ld_AddrUp = (bus.start) ? 1 : 0;
    	end
    TWO:begin
	NextState=(AddrReg[23:16]==N)?THREE:ONE;
	ld_AddrMid=1;
	end
    THREE: begin
	NextState = (bus.read) ? FOUR : FIVE;
    	ld_AddrLo = 1;
    	end
    FOUR: begin
    	NextState = (memDataAvail) ? ONE : FOUR;
    	dv = (memDataAvail) ? 1 : 0;
    	en_Data = (memDataAvail) ? 1 : 0;
    	end
    FIVE: begin
      NextState = (bus.dataValid) ? ONE: FIVE;
      ld_Data = (bus.dataValid) ? 1 : 0;
    	end
    endcase
    end
    
// *** testbench code
 always @(State)
    begin
    bit [2:0] delay;
    memDataAvail <= 0;
    if (State == FOUR)
    	begin
    	delay = $random;
    	repeat (2 + delay)
    		@(posedge bus.clock);
    	memDataAvail <= 1;
    	end
    end
endmodule

