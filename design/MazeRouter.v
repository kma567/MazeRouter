//-----------------------------------------------------
// Design Name : Maze Router
// File Name   : MazeRouter.v
// Authors	   : Yang Zhang
// Function    : Read "map" saved inside RAM and output routing 
//-----------------------------------------------------
`timescale 1ns/10ps
module maze_router (
reset		,
start		,
clk         , // Clock Input
address     , // Address Output
data_in        , // Data 
data_out,
cs          , // Chip Select
we          , // Write Enable/Read Enable
D			// Set the This signal tell testbench to prinout the content of SRAM
); 

parameter DATA_WIDTH = 8 ;
parameter ADDR_WIDTH = 8 ;

parameter GRID_WIDTH = 6 ;
parameter LENGTH_WIDTH = 6 ;
parameter TERMINAL_WIDTH = 6 ;

parameter MAX_MEM = 256 ;
parameter MAX_GRID = 64 ;
parameter MAX_LENGTH = 64 ;
parameter MAX_TERMINAL = 64 ;

//------------Input--------------- 
input					reset		;
input 					start	;
input                  clk         ;


input [DATA_WIDTH-1:0]  data_in       ;

//------------output---------------
output                  cs          ;
output                  we          ;
output [DATA_WIDTH-1:0]  data_out       ;
output [ADDR_WIDTH-1:0] address     ;
output D;

reg cs,we;
reg [DATA_WIDTH-1:0]  data_out       ;
reg [ADDR_WIDTH-1:0] address     ;
reg D	;

//---------------------------
reg [5:0] state;
reg [9:0] clk_count;

reg [DATA_WIDTH-1:0] grid [0:MAX_GRID-1];
reg [ADDR_WIDTH-1:0] read_index;
reg [GRID_WIDTH-1:0] terminal [0:MAX_TERMINAL-1];
reg [TERMINAL_WIDTH-1:0] terminal_index;
reg [GRID_WIDTH-1:0] min_terminal;

reg [DATA_WIDTH-1:0] wave_grid [0:MAX_GRID-1];
reg [GRID_WIDTH-1:0] wave_fifo [0:MAX_GRID-1];
reg [GRID_WIDTH-1:0] wave_grid_n;
reg [GRID_WIDTH-1:0] wave_fifo_rp, wave_fifo_wp, n_wave_fifo_wp;
reg [LENGTH_WIDTH-1:0] wave_group_length, wave_group_length_next, wave_neighbor_length;

reg [GRID_WIDTH-1:0] path [0:MAX_LENGTH-1];
reg [LENGTH_WIDTH-1:0] path_index;
reg [GRID_WIDTH-1:0] trace, n_trace;
reg [GRID_WIDTH-1:0] trace_grid_n;
reg T   ;

localparam
	IDLE 		= 		6'b000001,
	READ 		= 		6'b000010,
	WAVE 		= 		6'b000100,
	BACKTRACE 	= 		6'b001000,
	FAIL 		= 		6'b010000,
	DONE		=		6'b100000;
	

integer index;
integer i,j,out;

initial 
begin
	out = $fopen("router.txt","w");
	wait (D);
	#12;
	if (state == FAIL)
		$fwrite(out,"\n\n FAILED TO FIND A PATH!\n");
	else
		$fwrite(out,"\n\n FIND A PATH SUCESSFULLY!\n");
	$fclose(out);
end

always @(posedge clk)
begin
	if (T)
	begin
		$fwrite(out,"\n\n GRID:\n");
		j=0;
		for(i = 0; i < 64; i = i + 1)
		begin
			
			if(j==8)
			begin
				j=0;
				$fwrite(out,"\n");
			end
			$fwrite(out,"%h   ",grid[i]);
			j=j+1;
		end
		T <= 0;
	end
end



//--------------Code Starts Here------------------ 


always @(posedge clk)
begin
	if (reset == 1)
		begin
			state <= IDLE;			
		
			for (index = 0; index < MAX_GRID; index = index + 1)
			begin
				grid[index] <= 'bX;
				wave_fifo[index] <= 'bX;
				wave_grid[index] <= 8'hFF;
			end
			
			for (index = 0; index < MAX_LENGTH; index = index + 1)
			begin
				path[index] <= 'bX;
			end
			
			for (index = 0; index < MAX_TERMINAL; index = index + 1)
			begin
				terminal[index] <= 'bX;
			end			
			read_index <= 'bX;
			terminal_index <= 'bX;
			path_index <= 'bX;
			wave_grid_n <= 'bX;
			wave_group_length <= 'bX; 
			wave_group_length_next <= 'bX;
			trace <= 'bX;			
			wave_fifo_rp <= 'bX;
			wave_fifo_wp <= 'bX;			
			
			clk_count <= 0;
			T <= 0;

			address <= 8'h00;	
			
		end
	else
		begin
		
		clk_count <= clk_count + 1;
		
		case (state)
		
		IDLE:	
			begin
			
				if (start)
					begin
						address <= address + 1;
						read_index <= 0;
						terminal_index <= 0;
						path_index <= 0;						
						wave_fifo_rp <= 0;
						wave_fifo_wp <= 0;
						
						state <= READ;
					end					
			end
			
		READ:
			begin
			
				if (address == MAX_GRID - 1)
					address <= 8'h80;
				else
					address <= address + 1;
					
				if (read_index < MAX_GRID)
					begin
						grid[read_index] <= data_in;
						read_index <= read_index + 1;
					end
				else if (data_in < MAX_GRID && grid[data_in] == 8'hEE)
					begin
						terminal[terminal_index] <= data_in;
						grid[data_in] <= 8'h00;
						terminal_index <= terminal_index + 1;
					end
				else if (data_in === 8'hxx)
					begin
						if (terminal_index > 1)
						begin
							min_terminal = terminal[0];
							for (index = 0; index < terminal_index; index = index + 1)
							begin
								if (terminal[index] < min_terminal)
									min_terminal = terminal[index];
							end
							wave_fifo[wave_fifo_wp] <= min_terminal; //start from the min point
							wave_fifo_wp <= wave_fifo_wp + 1;
							wave_grid[min_terminal] <= 0;							
							wave_grid_n <= 0;
							wave_group_length <= 1; 
							wave_group_length_next <= 0;
							
							terminal_index <= terminal_index - 1;							
							path[0] <= min_terminal;
							path_index <= path_index + 1;
								
							state <= WAVE;
						end
						else
							state <= FAIL;
					end
					
			end		
			
		WAVE : 			
			begin
				n_wave_fifo_wp = wave_fifo_wp;
				wave_neighbor_length = 0;
				
				if (wave_fifo_rp != wave_fifo_wp)
				begin
					if (grid[wave_fifo[wave_fifo_rp]] == 8'h00 && wave_grid[wave_fifo[wave_fifo_rp]])
					begin
						wave_fifo_wp <= wave_fifo_rp;
						trace <= wave_fifo[wave_fifo_rp];
						path[path_index] <= wave_fifo[wave_fifo_rp];
						path_index <= path_index + 1;						
						terminal_index <= terminal_index - 1;						
						address <= wave_fifo[wave_fifo_rp];
						data_out <= 8'h00;
						
						state <= BACKTRACE;
					end
					else
					begin
						if (wave_fifo[wave_fifo_rp] % 8)
						begin
							if (grid[wave_fifo[wave_fifo_rp] - 1] != 8'hFF && wave_grid[wave_fifo[wave_fifo_rp] - 1] == 8'hFF)
							begin
								wave_fifo[n_wave_fifo_wp] <= wave_fifo[wave_fifo_rp] - 1;
								wave_grid[wave_fifo[wave_fifo_rp] - 1] <= wave_grid_n + 1;
								n_wave_fifo_wp = n_wave_fifo_wp + 1;
								wave_neighbor_length = wave_neighbor_length + 1;
							end
						end
						if (wave_fifo[wave_fifo_rp] % 8 < 7)
						begin
							if (grid[wave_fifo[wave_fifo_rp] + 1] != 8'hFF && wave_grid[wave_fifo[wave_fifo_rp] + 1] == 8'hFF)
							begin
								wave_fifo[n_wave_fifo_wp] <= wave_fifo[wave_fifo_rp] + 1;
								wave_grid[wave_fifo[wave_fifo_rp] + 1] <= wave_grid_n + 1;
								n_wave_fifo_wp = n_wave_fifo_wp + 1;
								wave_neighbor_length = wave_neighbor_length + 1;
							end
						end
						if (wave_fifo[wave_fifo_rp] > 7)
						begin
							if (grid[wave_fifo[wave_fifo_rp] - 8] != 8'hFF && wave_grid[wave_fifo[wave_fifo_rp] - 8] == 8'hFF)
							begin
								wave_fifo[n_wave_fifo_wp] <= wave_fifo[wave_fifo_rp] - 8;
								wave_grid[wave_fifo[wave_fifo_rp] - 8] <= wave_grid_n + 1;
								n_wave_fifo_wp = n_wave_fifo_wp + 1;
								wave_neighbor_length = wave_neighbor_length + 1;
							end
						end
						if (wave_fifo[wave_fifo_rp] < 56)
						begin
							if (grid[wave_fifo[wave_fifo_rp] + 8] != 8'hFF && wave_grid[wave_fifo[wave_fifo_rp] + 8] == 8'hFF)
							begin
								wave_fifo[n_wave_fifo_wp] <= wave_fifo[wave_fifo_rp] + 8;
								wave_grid[wave_fifo[wave_fifo_rp] + 8] <= wave_grid_n + 1;
								n_wave_fifo_wp = n_wave_fifo_wp + 1;
								wave_neighbor_length = wave_neighbor_length + 1;
							end
						end
							
						wave_fifo_rp <= wave_fifo_rp + 1;
						wave_fifo_wp <= n_wave_fifo_wp;
						
						if (wave_group_length == 1)
						begin
							wave_group_length <= wave_group_length_next + wave_neighbor_length;
							wave_group_length_next <= 0;
							wave_grid_n <= wave_grid_n + 1;
						end
						else
						begin
							wave_group_length <= wave_group_length - 1;
							wave_group_length_next <= wave_group_length_next + wave_neighbor_length;
						end
					end
				end
				else
					state <= FAIL;

			end			
		
		BACKTRACE: 
		
			begin				
				trace_grid_n = wave_grid_n;
				n_trace = trace;
				
				if (wave_grid[trace])
				begin
					if (n_trace % 8)
					begin
						if (wave_grid[trace - 1] < trace_grid_n)
						begin
							trace_grid_n = wave_grid[trace - 1];
							n_trace = trace - 1;
						end
					end
							
					if (n_trace % 8 < 7)
					begin
						if (wave_grid[trace + 1] < trace_grid_n)
						begin
							trace_grid_n = wave_grid[trace + 1];
							n_trace = trace + 1;
						end
					end
					
					if (n_trace > 7)
					begin
						if (wave_grid[trace - 8] < trace_grid_n)
						begin
							trace_grid_n = wave_grid[trace - 8];
							n_trace = trace - 8;
						end
					end
					
					if (n_trace < 56)
						if (wave_grid[trace + 8] < trace_grid_n)
						begin
							trace_grid_n = wave_grid[trace + 8];
							n_trace = trace + 8;
						end
						
					trace <= n_trace;
					wave_grid_n <= trace_grid_n;					
					grid[trace] <= 8'h00;					
					path[path_index] <= trace;
					path_index <= path_index + 1;
					
				end				
				else 
				begin
					T <= 1;	
					for (index = 0; index < MAX_GRID; index = index + 1)
						wave_grid[index] <= 8'hFF;
						
					n_wave_fifo_wp = wave_fifo_wp;						
					for (index = 0; index < path_index; index = index + 1)
					begin
						wave_grid[path[index]] <= 8'h00; 	//overwrite FF
						wave_fifo[n_wave_fifo_wp] <= path[index];							
						n_wave_fifo_wp = n_wave_fifo_wp + 1;							
					end
					wave_fifo_wp <= n_wave_fifo_wp;
					wave_group_length <= path_index;
					wave_group_length_next <= 0;
					wave_grid_n <= 0;
					
					if (terminal_index)	
						state <= WAVE;
					else
						state <= DONE;
				end
				
				address <= n_trace;
					
			end
			
		FAIL: state <= FAIL;
		
		DONE: state <= DONE;
		
		default: state <= FAIL;
		endcase
	end	

end	

always @(*)
begin
	if ((state == IDLE && start) || state == READ || state == BACKTRACE)
		cs <= 1;
	else
		cs <= 0;
		
	if (state == BACKTRACE)
		we <= 1;
	else
		we <= 0;
	
	if (state == DONE || state == FAIL)
		D <= 1;
	else
		D <= 0;
end

endmodule // End of Module
