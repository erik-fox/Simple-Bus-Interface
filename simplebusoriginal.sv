module top;

logic clock = 1;
logic resetN = 0;
tri dataValid, start, read;
tri [7:0] data, address;

always #5 clock = ~clock;

initial #2 resetN = 1;

ProcessorIntThread P(.*);
MemoryIntThread M(.*);

endmodule





module ProcessorIntThread(
    input logic resetN, clock,
    output logic start, read,
    inout logic dataValid,
    output logic [7:0] address,
    inout logic [7:0] data);

logic en_AddrUp, en_AddrLo, ld_Data, en_Data, access = 0;
logic doRead, wDataRdy, dv;
logic [7:0] DataReg;
logic [15:0] AddrReg;

enum {MA,MB,MC,MD} State, NextState;

assign data = (en_Data) ? DataReg : 'bz;
assign dataValid = (State == MD) ? dv : 1'bz;

always_comb
    if (en_AddrLo) address = AddrReg[7:0];
    else if (en_AddrUp) address = AddrReg[15:8];
    else address = 'bz;
    
always_ff @(posedge clock)
    if (ld_Data) DataReg <= data;
    
always_ff @(posedge clock, negedge resetN)
    if (!resetN) State <= MA;
    else State <= NextState;
    
    
always_comb
    begin
    start = 0;
    en_AddrUp = 0;
    en_AddrLo = 0;
    read = 0;
    ld_Data = 0;
    en_Data = 0;
    dv = 0;
    
    case(State)
    MA:	begin
    	NextState = (access) ? MB : MA;
    	start = (access) ? 1 : 0;
    	en_AddrUp = (access) ? 1 : 0;
    	end
    MB:	begin
    	NextState = (doRead) ? MC : MD;
    	en_AddrLo = 1;
    	read = (doRead) ? 1 : 0;
    	end
    MC:	begin
    	NextState = (dataValid) ? MA : MC;
    	ld_Data = (dataValid) ? 1 : 0;
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
@(posedge clock) access <= 0;
@(posedge clock);
wait (State == MA); 
repeat (2) @(posedge clock);
end
endtask


task ReadMem(input [15:0] Avalue);   
begin
access <= 1;
doRead <= 1;
wDataRdy <= 0;
AddrReg <= Avalue;
@(posedge clock) access <= 0;
@(posedge clock);
wait (State == MA); 
repeat (2) @(posedge clock);
end
endtask


initial
begin
repeat (2) @(posedge clock);
// Note this is from the textbook but is *not* a good test!!
WriteMem(16'h0406, 8'hDC);
ReadMem(16'h0406);
WriteMem(16'h0407, 8'hAB);
ReadMem(16'h0406);
ReadMem(16'h0407);
$finish;
end
    
endmodule





module MemoryIntThread(
    input logic resetN, clock,
    input logic start, read,
    inout logic dataValid,
    input logic [7:0] address,
    inout logic [7:0] data);
    
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

    
assign data = (en_Data) ? MemData : 'bz;
assign dataValid = (State == SC) ? dv : 1'bz;


always @(AddrReg, ld_Data)
    MemData = Mem[AddrReg];
    
always_ff @(posedge clock)
    if (ld_AddrUp) AddrReg[15:8] <= address;
    
always_ff @(posedge clock)
    if (ld_AddrLo) AddrReg[7:0] <= address;

always @(posedge clock)
    begin
    if (ld_Data)
        begin
        DataReg <= data;
        Mem[AddrReg] <= data;
        end
    end
    
always_ff @(posedge clock, negedge resetN)
  if (!resetN) State <= SA;
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
    	NextState = (start) ? SB : SA;
    	ld_AddrUp = (start) ? 1 : 0;
    	end
    SB: begin
    	NextState = (read) ? SC : SD;
    	ld_AddrLo = 1;
    	end
    SC: begin
    	NextState = (memDataAvail) ? SA : SC;
    	dv = (memDataAvail) ? 1 : 0;
    	en_Data = (memDataAvail) ? 1 : 0;
    	end
    SD: begin
    	NextState = (dataValid) ? SA: SD;
    	ld_Data = (dataValid) ? 1 : 0;
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






