module top;
logic clock=1, resetN=0;
tri dataValid, start, read;
tri [7:0] data, address;

always #5 clock = ~clock;

initial #2 resetN=1;

ProcIntThread M(.*);
MemIntThread S(.*);

endmodule: top

module ProcIntThread (input  logic resetN, clock, output logic start,  read, inout  logic dataValid, output logic [7:0] address, inout  logic [7:0] data);
logic en_AddrUp, en_AddrLo, ld_Data, en_Data, access=0,doRead, wDataRdy, dv;
logic [7:0]DataReg;
logic [15:0]AddrReg;
  
enum {MA,MB,MC,MD} State, NextState;
assign data = (en_Data)? DataReg: 'bz;
assign dataValid = (State==MD)? dv: 1'bz;
  
always_comb
	if(en_AddrLo)
        	address = AddrReg[7:0];
    	else if (en_AddrUp)
        	address = AddrReg[15:8];
    	else
        	address = 'bz;
 always@(posedge clock)
 	if(ld_Data)
        	DataReg<=data;
 always_ff@(posedge clock, negedge resetN)
    	if(~resetN)
        	State<=MA;
    	else
        	State<=NextState;
  
 always_comb
 begin
 	start=0;
      	en_AddrUp=0;
      	en_AddrLo=0;
      	read=0;
      	ld_Data=0;
      	en_Data=0;
      	dv=0;
      	case(State)
        	MA:
            	begin
              		NextState=(access)?MB:MA;
              		start=(access)?1:0;
              		en_AddrUp=(access)?1:0;
            	end
          	MB:
            	begin
              		NextState=(doRead)?MC:MD;
              		en_AddrLo=1;
              		read=(doRead)?1:0;
            	end
          	MC:
            	begin
              		NextState=(dataValid)?MA:MC;
            		ld_Data=(dataValid)?1:0;
            	end
          	MD:
            	begin
              		NextState=(wDataRdy)?MA:MD;
              		en_Data=(wDataRdy)?1:0;
              		dv=(wDataRdy)?1:0;
            	end
      	endcase
end
endmodule

module MemIntThread (input logic resetN, clock, start, read, inout logic dataValid, input logic [7:0]address, inout logic [7:0] data);
logic [7:0]Mem[16'hFFFF:0],MemData;
logic ld_AddrUp, ld_AddrLo, memDataAvail=0, en_Data, ld_Data, dv;
logic [7:0] DataReg;
logic [15:0]AddrReg;
enum {SA,SB,SC,SD} State, NextState;
  
initial
begin
	for(int i=0; i<=16'hFFFF;i++)
        	Mem[i]=i[7:0];
end
 
assign data =(en_Data)? MemData:'bz;
assign dataValid =(State==SC)? dv:1'bz;
  
always@(AddrReg, ld_Data)
	MemData=Mem[AddrReg];

always_ff@(posedge clock)
    	if(ld_AddrUp) 
      		AddrReg[15:8]<=address;

always_ff@(posedge clock)
      	if(ld_AddrLo) 
        	AddrReg[7:0]<=address;
  
always@(posedge clock)
begin
      	if(ld_Data)
        begin
        	DataReg<=data;
          	Mem[AddrReg]<=data;
        end
 end
  
always_ff@(posedge clock, negedge resetN)
    	if(~resetN) 
      		State<=SA;
    	else 
      		State<=NextState;
  
always_comb 
begin
      	ld_AddrUp=0;
      	ld_AddrLo=0;
      	dv=0;
      	en_Data=0;
      	ld_Data=0;
      	case(State)
        	SA:
            	begin
              		NextState=(start)?SB:SA;
              		ld_AddrUp=(start)?1:0;
            	end
          	SB:
            	begin
              		NextState=(read)?SC:SD;
              		ld_AddrLo=1;
            	end
          	SC:
            	begin
              		NextState=(memDataAvail)?SA:SC;
              		dv=(memDataAvail)?1:0;
              		en_Data=(memDataAvail)?1:0;
            	end
          	SD:
            	begin
              		NextState=(dataValid)?SA:SD;
              		ld_Data=(dataValid)?1:0;
            	end
      	endcase
end
endmodule
    
    

