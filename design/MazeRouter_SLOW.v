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
parameter LENGTH_WIDTH = 5 ;
parameter TERMINAL_WIDTH = 3 ;

parameter MAX_MEM = 256 ;
parameter MAX_GRID = 64 ;
parameter MAX_LENGTH = 32 ;
parameter MAX_TERMINAL = 8 ;

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
reg T   ;

//---------------------------
reg [6:0] state;

reg [DATA_WIDTH-1:0] grid [0:MAX_GRID-1];
reg [DATA_WIDTH-1:0] wave_grid [0:MAX_GRID-1];
reg [DATA_WIDTH-1:0] wave_mark [0:MAX_GRID-1];
reg [DATA_WIDTH-1:0] wave_neighbor [0:MAX_GRID-1];
reg [GRID_WIDTH-1:0] path [0:MAX_LENGTH-1];
reg [GRID_WIDTH-1:0] terminal [0:MAX_TERMINAL-1];
reg [GRID_WIDTH-1:0] min_terminal;

reg [ADDR_WIDTH-1:0] read_index;
reg [LENGTH_WIDTH-1:0] path_index;
reg [TERMINAL_WIDTH-1:0] terminal_index;


reg [GRID_WIDTH-1:0] wave_grid_n;
reg [GRID_WIDTH-1:0] wave_mark_i, wave_neighbor_i, n_wave_neighbor_i;
reg reached;

reg [GRID_WIDTH-1:0] trace, n_trace;
reg [GRID_WIDTH-1:0] trace_grid_n;


localparam
	IDLE 		= 		7'b0000001,
	READ 		= 		7'b0000010,
	WAVE_1 		= 		7'b0000100,
	WAVE_2 		= 		7'b0001000,
	BACKTRACE 	= 		7'b0010000,
	FAIL 		= 		7'b0100000,
	DONE		=		7'b1000000;
	

integer index;
integer i,j,out;

initial 
begin
	out = $fopen("output_router.txt","w");
	wait (D);
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
		
		$fwrite(out,"\n\n WAVE_GRID:\n");
		j=0;
		for(i = 0; i < 64; i = i + 1)
		begin
			
			if(j==8)
			begin
				j=0;
				$fwrite(out,"\n");
			end
			$fwrite(out,"%h   ",wave_grid[i]);
			j=j+1;
		end
		
		$fwrite(out,"\n\n NEIGHBOR:\n");
		j=0;
		for(i = 0; wave_neighbor[i] != 8'hFF ; i = i + 1)
		begin
			
			if(j==8)
			begin
				j=0;
				$fwrite(out,"\n");
			end
			$fwrite(out,"%0o   ",wave_neighbor[i]);
			j=j+1;
		end
		T <= 0;
	end
end



//--------------Code Starts Here------------------ 


always@(posedge clk)
begin
	if (reset == 1)
		begin
			state <= IDLE;			
		
			for (index = 0; index < MAX_GRID; index = index + 1)
			begin
				grid[index] <= 8'hFF;
				wave_grid[index] <= 8'hFF;
				wave_mark[index] <= 8'hFF;
			end
			
			address <= 8'h00;
			T <= 0;			
			
		end
	else
		begin
		
		case (state)
		
		IDLE:	
			begin
			
				if (start)
					begin
						address <= address + 1;
						read_index <= 0;
						terminal_index <= 0;
						path_index <= 0;
						
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
				else
					begin
						if (terminal_index)
						begin
							min_terminal = terminal[0];
							for (index = 0; index < terminal_index; index = index + 1)
							begin
								if (terminal[index] < min_terminal)
									min_terminal = terminal[index];
							end
							wave_mark[0] <= min_terminal;
							wave_grid[min_terminal] <= 0;
							wave_grid_n <= 0;
							wave_mark_i <= 0;
							wave_neighbor_i <= 0;	
							
							terminal_index <= terminal_index - 1;							
							path[0] <= min_terminal;
							path_index <= path_index + 1;			
							
							state <= WAVE_1;
						end
						else
							state <= DONE;
					end
					
			end
					
			
			
		WAVE_1 : 
		
			begin				
				n_wave_neighbor_i = wave_neighbor_i;
				reached = 0;
				
				if (grid[wave_mark[wave_mark_i]] == 8'h00 && wave_grid[wave_mark[wave_mark_i]])
					reached = 1;
				else
				begin
					if (wave_mark[wave_mark_i] % 8)
						begin
							if (grid[wave_mark[wave_mark_i] - 1] != 8'hFF && wave_grid[wave_mark[wave_mark_i] - 1] == 8'hFF)
							begin
								wave_neighbor[n_wave_neighbor_i] <= wave_mark[wave_mark_i] - 1;
								wave_grid[wave_mark[wave_mark_i] - 1] <= wave_grid_n + 1;
								n_wave_neighbor_i = n_wave_neighbor_i + 1;
							end
						end
					if (wave_mark[wave_mark_i] % 8 < 7)
						begin
							if (grid[wave_mark[wave_mark_i] + 1] != 8'hFF && wave_grid[wave_mark[wave_mark_i] + 1] == 8'hFF)
							begin
								wave_neighbor[n_wave_neighbor_i] <= wave_mark[wave_mark_i] + 1;
								wave_grid[wave_mark[wave_mark_i] + 1] <= wave_grid_n + 1;
								n_wave_neighbor_i = n_wave_neighbor_i + 1;
							end
						end
					if (wave_mark[wave_mark_i] > 7)
						begin
							if (grid[wave_mark[wave_mark_i] - 8] != 8'hFF && wave_grid[wave_mark[wave_mark_i] - 8] == 8'hFF)
							begin
								wave_neighbor[n_wave_neighbor_i] <= wave_mark[wave_mark_i] - 8;
								wave_grid[wave_mark[wave_mark_i] - 8] <= wave_grid_n + 1;
								n_wave_neighbor_i = n_wave_neighbor_i + 1;
							end
						end
					if (wave_mark[wave_mark_i] < 56)
						begin
							if (grid[wave_mark[wave_mark_i] + 8] != 8'hFF && wave_grid[wave_mark[wave_mark_i] + 8] == 8'hFF)
							begin
								wave_neighbor[n_wave_neighbor_i] <= wave_mark[wave_mark_i] + 8;
								wave_grid[wave_mark[wave_mark_i] + 8] <= wave_grid_n + 1;
								n_wave_neighbor_i = n_wave_neighbor_i + 1;
							end
						end
				end

				
				if (reached)
				begin
					trace <= wave_mark[wave_mark_i];
					
					wave_mark_i <= 0;
					wave_neighbor_i <= 0;
					for (index = 0; index < wave_neighbor_i; index = index + 1)
						wave_neighbor[index] <= 8'hFF;
					
					path[path_index] <= wave_mark[wave_mark_i];
					path_index <= path_index + 1;					
					
					terminal_index <= terminal_index - 1;
					
					address <= wave_mark[wave_mark_i];
					data_out <= 8'h00;
					
					state <= BACKTRACE;
				end					
				else if (wave_mark[wave_mark_i + 1] == 8'hFF)
				begin
					T <= 1;
					wave_neighbor_i <= n_wave_neighbor_i;
					
					state <= WAVE_2;
				end
				else 
				begin					
					wave_mark_i <= wave_mark_i + 1;
					wave_neighbor_i <= n_wave_neighbor_i;
				end

			end			
		
		WAVE_2 :
		
			begin
				for (index = 0; index < wave_neighbor_i; index = index + 1)
				begin
					wave_mark[index] <= wave_neighbor[index];
					wave_neighbor[index] <= 8'hFF;
				end
				if (wave_neighbor[0] == 8'hFF)
					state <= FAIL;
				else
				begin
					wave_mark_i <= 0;
					wave_neighbor_i <= 0;
					wave_grid_n <= wave_grid_n + 1;
					
					state <= WAVE_1;
				end
			end
		
		BACKTRACE: 
		
			begin
			
				T <= 1;
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
					wave_grid[trace] <= 8'hEE;
					
					path[path_index] <= trace;
					path_index <= path_index + 1;
					
				end
				
				else if (terminal_index)
					begin
					
						for (index = 0; index < path_index; index = index + 1)
							wave_mark[index] <= path[index];
							
						for (index = 0; index < MAX_GRID; index = index + 1)
						begin
							if (wave_grid[index] == 8'hEE)
								wave_grid[index] <= 8'h00;
							else if (wave_grid[index])
								wave_grid[index] <= 8'hFF;
						end
						
						wave_grid_n <= 0;
						//wave_mark_i <= 0;
						//wave_neighbor_i <= 0;
						
						state <= WAVE_1;
					end
				else				
					state <= DONE;
					
				address <= n_trace;
					
					
			end
			
		FAIL: state <= FAIL;
		
		DONE: state <= DONE;

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
	
	if (state == FAIL || state == DONE)
		D <= 1;
	else
		D <= 0;
end

endmodule // End of Module
