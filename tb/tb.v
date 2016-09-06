/////////////////////////////////////////////////////////////////
//       testbench: tb.v  second version
/////////////////////////////////////////////////////////////////
`timescale 1ns/10ps
module tb;
parameter DATA_WIDTH = 8 ;
parameter ADDR_WIDTH = 8 ;

wire [ADDR_WIDTH-1:0]ADDRESS;
wire [DATA_WIDTH-1:0]DATA_1;
wire [DATA_WIDTH-1:0]DATA_2;
wire CS,WE,D;

reg RESET,START,CLK;

maze_router my_maze_router(
.reset(RESET)		,
.start(START)		,
.clk(CLK)         , // Clock Input
.address(ADDRESS)     , // Address Input
.data_in(DATA_1)        , // Data 
.data_out(DATA_2),
.cs(CS)          , // Chip Select
.we(WE)          , // Write Enable/Read Enable
.D(D)
);

sram my_sram(
.clk(CLK)         , // Clock Input
.address(ADDRESS)     , // Address Input
.data_in(DATA_2)        , // Data 
.data_out(DATA_1),
.cs(CS)          , // Chip Select
.we(WE)          ,// Write Enable/Read Enable
.D(D)
); 





initial 
begin
CLK = 0; 
RESET=1;
START=0;
#10;
START=1;
RESET=0;
#20;
START=0;
#20; 
wait (D);
#20;
$stop;
end
always #5 CLK=~CLK;
endmodule





