interface simplebus (input logic clock, resetN);
  tri dataValid, start, read;
  tri [7:0] data, address; 
 
  modport leader (input resetN, 
                  input clock, 
                  output start, 
                  output read,
                  inout dataValid,
                  output address,
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

logic clock = 1;
logic resetN = 0;
  
simplebus procmemif(clock,resetN);

always #5 clock = ~clock;

initial #2 resetN = 1;

  ProcessorIntThread P(procmemif.leader);
  MemoryIntThread M(procmemif.follower);

endmodule


module ProcessorIntThread(simplebus bus);

logic en_AddrUp, en_AddrLo, ld_Data, en_Data, access = 0;
logic doRead, wDataRdy, dv;
logic [7:0] DataReg;
logic [15:0] AddrReg;

enum {MA,MB,MC,MD} State, NextState;

assign bus.data = (en_Data) ? DataReg : 'bz;
assign bus.dataValid = (State == MD) ? dv : 1'bz;

always_comb
    if (en_AddrLo) bus.address = AddrReg[7:0];
    else if (en_AddrUp) bus.address = AddrReg[15:8];
    else bus.address = 'bz;
    
always_ff @(posedge bus.clock)
    if (ld_Data) DataReg <= bus.data;
    
always_ff @(posedge bus.clock, negedge bus.resetN)
    if (!bus.resetN) State <= MA;
    else State <= NextState;
    
    
always_comb
    begin
    bus.start = 0;
    en_AddrUp = 0;
    en_AddrLo = 0;
    bus.read = 0;
    ld_Data = 0;
    en_Data = 0;
    dv = 0;
    
    case(State)
    MA:	begin
    	NextState = (access) ? MB : MA;
    	bus.start = (access) ? 1 : 0;
    	en_AddrUp = (access) ? 1 : 0;
    	end
    MB:	begin
    	NextState = (doRead) ? MC : MD;
    	en_AddrLo = 1;
    	bus.read = (doRead) ? 1 : 0;
    	end
    MC:	begin
    	NextState = (bus.dataValid) ? MA : MC;
    	ld_Data = (bus.dataValid) ? 1 : 0;
    	end
    MD:	begin
    	NextState = (wDataRdy) ? MA : MD;
    	en_Data = (wDataRdy) ? 1 : 0;
    	dv = (wDataRdy) ? 1 : 0;
    	end
    endcase
    end

task WriteMem(input [15:0] Avalue, input [7:0] Dvalue);   
begin
access <= 1;
doRead <= 0;
wDataRdy <= 1;
AddrReg <= Avalue;
DataReg <= Dvalue;
@(posedge bus.clock) access <= 0;
@(posedge bus.clock);
wait (State == MA); 
repeat (2) @(posedge bus.clock);
end
endtask


task ReadMem(input [15:0] Avalue);   
begin
access <= 1;
doRead <= 1;
wDataRdy <= 0;
AddrReg <= Avalue;
  @(posedge bus.clock) access <= 0;
  @(posedge bus.clock);
wait (State == MA); 
  repeat (2) @(posedge bus.clock);
end
endtask


initial
begin
repeat (2) @(posedge bus.clock);
// Note this is from the textbook but is *not* a good test!!
WriteMem(16'h0406, 8'hDC);
ReadMem(16'h0406);
WriteMem(16'h0407, 8'hAB);
ReadMem(16'h0406);
ReadMem(16'h0407);
$finish;
end
    
endmodule

endmodule





module MemoryIntThread(simplebus bus);
    
logic [7:0] Mem[16'hFFFF:0], MemData;
logic ld_AddrUp, ld_AddrLo, memDataAvail = 0;
logic en_Data, ld_Data, dv;
logic [7:0] DataReg;
logic [15:0] AddrReg;

enum {SA, SB, SC, SD} State, NextState;


initial
    begin
    for (int i = 0; i < 16'hFFFF; i++)
        Mem[i] <= 0;
    end

    
assign bus.data = (en_Data) ? MemData : 'bz;
assign bus.dataValid = (State == SC) ? dv : 1'bz;


always @(AddrReg, ld_Data)
    MemData = Mem[AddrReg];
    
always_ff @(posedge bus.clock)
    if (ld_AddrUp) AddrReg[15:8] <= bus.address;
    
always_ff @(posedge bus.clock)
  if (ld_AddrLo) AddrReg[7:0] <= bus.address;

always @(posedge bus.clock)
    begin
    if (ld_Data)
        begin
        DataReg <= bus.data;
        Mem[AddrReg] <= bus.data;
        end
    end
    
always_ff @(posedge bus.clock, negedge bus.resetN)
  if (!bus.resetN) State <= SA;
  else State <= NextState;
  
always_comb
    begin
    ld_AddrUp = 0;
    ld_AddrLo = 0;
    dv = 0;
    en_Data = 0;
    ld_Data = 0;
    
    case (State)
    SA: begin
      NextState = (bus.start) ? SB : SA;
      ld_AddrUp = (bus.start) ? 1 : 0;
    	end
    SB: begin
      NextState = (bus.read) ? SC : SD;
    	ld_AddrLo = 1;
    	end
    SC: begin
    	NextState = (memDataAvail) ? SA : SC;
    	dv = (memDataAvail) ? 1 : 0;
    	en_Data = (memDataAvail) ? 1 : 0;
    	end
    SD: begin
      NextState = (bus.dataValid) ? SA: SD;
      ld_Data = (bus.dataValid) ? 1 : 0;
    	end
    endcase
    end
    
// *** testbench code
 always @(State)
    begin
    bit [2:0] delay;
    memDataAvail <= 0;
    if (State == SC)
    	begin
    	delay = $random;
    	repeat (2 + delay)
    		@(posedge clock);
    	memDataAvail <= 1;
    	end
    end
endmodule

