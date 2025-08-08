// Code your design here
module axis_slave
  
  #(
    parameter MEM_SIZE = 256,
    parameter AXI_WIDTH = 8
  )
  (axiInterface.slave ifc);
  
  //register bank to store single byte of data
  logic [AXI_WIDTH-1:0] mem [MEM_SIZE-1:0];
  logic [$clog2(MEM_SIZE)-1:0] addr_ctr;
  
  always @ (posedge ifc.clk)begin
    
    if(ifc.reset) 
      ifc.TREADY <= 1;  //always ready to accept data 

    else begin
      if(ifc.TVALID ) begin
        mem [addr_ctr] <= ifc.TDATA;
        addr_ctr ++;
      end
    end
    
  end
  
  assign ifc.Tdone = (ifc.TVALID && ifc.TLAST) ? 1:0;
  
endmodule 


interface axiInterface (input clk);
  
  logic [7:0] TDATA;
  logic TVALID;
  logic reset;
  logic TLAST;
  logic TREADY;
  logic Tdone;
  
  modport slave (input TDATA, TVALID, reset, TLAST, clk, output TREADY, Tdone);
  
endinterface 
