//-----------------------------------------------------
// Design Name 	: sram
// File Name   	: sram.v
// Authors	    : Yang Zhang
// Function    	: Synchronous read write RAM 
//-----------------------------------------------------
`timescale 1ns/10ps
module sram (
clk         , // Clock Input
address     , // Address Input
data_in        , // Data 
data_out,
cs          , // Chip Select
we          , // Write Enable/Read Enable
D
); 

parameter DATA_WIDTH = 8 ;
parameter ADDR_WIDTH = 8 ;
parameter RAM_DEPTH = 1 << ADDR_WIDTH;

//------------Input--------------- 
input                  clk         ;
input [ADDR_WIDTH-1:0] address     ;
input                  cs          ;
input                  we          ;
input [DATA_WIDTH-1:0]  data_in       ;
input D;

//------------output---------------
output [DATA_WIDTH-1:0]  data_out       ;

//---------generate a file that print out memory content/filling results
integer out;
integer i,j;

reg [DATA_WIDTH-1:0]  data_out       ;
//------------SRAM memory---------------- 
reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
// -------------Initialize the memory--------------
initial begin
	out = $fopen("output.txt","w");
	#12;
	$readmemh("memory.list", mem);
	wait(D);
	#10;
	j=0;
	for(i = 0; i < 64; i = i + 1)
	begin
		
		if(j==8)
		begin
			j=0;
			$fwrite(out,"\n");
		end
		$fwrite(out,"%h   ",mem[i]);
		j=j+1;
	end
	
	$fclose(out);
end

//--------------Code Starts Here------------------ 


// Memory Write Block 
// Write Operation : When we = 1, cs = 1
always @ (posedge clk)
begin : MEM_WRITE
   if ( cs && we ) begin
       mem[address] <= data_in;
   end
end

// Memory Read Block 
// Read Operation : When we = 0,  cs = 1
always @ (posedge clk)
begin : MEM_READ
  if (cs && !we) begin
    data_out <= mem[address];
  end
end

endmodule // End of Module sram
