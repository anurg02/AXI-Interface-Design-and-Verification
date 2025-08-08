// Code your design here
`timescale 1ns/1ps
 module AXI_lite_master 
#(parameter AXI_WIDTH = 8,
  parameter AXI_ADDR_WIDTH = 6,
  parameter RESP_WIDTH = 3,
  parameter MEM_WIDTH = 8 //memory size
  )
  (AXIL_Interface.master _mifc);
  
    always @ (posedge _mifc.clk)begin
    
        if(_mifc.rst) begin
            _mifc.M_AWVALID <= 1'b0;
            _mifc.M_AWADDR <= 0;
            _mifc.M_WVALID <= 1'b0;
            _mifc.M_WDATA <= 0;
            _mifc.M_WLAST <= 0;
            _mifc.M_BREADY <= 1'b1; //always ready to receive write response
            _mifc.M_ARVALID <= 1'b0;
            _mifc.M_ARADDR <= 0;
            _mifc.M_RREADY <= 1'b1; //always ready to receive read data 
            _mifc.readData <= 0;
       end
       else begin
          if(_mifc.writeEn) begin
          //write channel
            if(_mifc.M_WVALID && _mifc.S_WREADY) begin  //once the data is accepted by the slave assert valids as zero
                _mifc.M_AWVALID <= 1'b0;
                _mifc.M_WVALID <= 1'b0;
            end
            if(!_mifc.M_AWVALID) begin
                _mifc.M_AWVALID <= 1'b1; //assert valid for address
                _mifc.M_AWADDR <= _mifc.wr_addr; //set address
            end
            if(!_mifc.M_WVALID) begin
                _mifc.M_WVALID <= 1'b1;
                _mifc.M_WDATA <= _mifc.data;
            end
          end
          //response channel       
        else begin
          _mifc.M_AWVALID <= 1'b0;
          _mifc.M_WVALID <= 1'b0;
        end
        if(_mifc.readEn) begin
              
            //read channel 
          if(!_mifc.M_ARVALID) begin
              _mifc.M_ARVALID <= 1;
              _mifc.M_ARADDR <= _mifc.rd_addr;
          end
          if (_mifc.M_ARVALID && _mifc.S_ARREADY) begin
              _mifc.M_ARVALID <= 1'b0; //once the address is accepted by the slave, deassert valid
          end
          if(_mifc.S_RVALID && _mifc.M_RREADY) begin
              _mifc.readData <= _mifc.S_RDATA;
          end
        end
        else 
            _mifc.M_ARVALID <= 1'b0;
       end
        
    end
       
 endmodule


`timescale 1ns / 1ps
module AXI_lite_slave
#(parameter MEM_WIDTH = 64,
  parameter AXI_WIDTH = 64,
  parameter AXI_ADDR_WIDTH = 6,
  parameter AXI_RESP_WIDTH = 3
 )
  (AXIL_Interface.slave _sifc);
    
  logic [AXI_WIDTH-1:0] register [MEM_WIDTH-1:0];
  logic [AXI_ADDR_WIDTH-1:0] rd_addr;

  always @ (posedge _sifc.clk) begin
        
    if (_sifc.rst) begin
            _sifc.S_AWREADY <= 1'b1;  //default accept write address request
            _sifc.S_WREADY <= 1'b1;  //default accept write data request
            _sifc.S_BVALID <= 1'b0;
            _sifc.S_BRESP <= 3'b000;
            _sifc.S_ARREADY <= 1'b1;  //default- accepts read request 
            _sifc.S_RVALID <= 1'b0;   
            _sifc.S_RDATA <= 0;
            _sifc.S_RRESP <= 3'b000;
    end
        
    else begin 
        //Write Addr channel
      if (_sifc.writeEn) begin
        
        //write data and resp channel 
        if((_sifc.M_AWVALID && _sifc.S_AWREADY) && (_sifc.M_WVALID && _sifc.S_WREADY))begin //after valid data transaction
            register[_sifc.M_AWADDR] <= _sifc.M_WDATA;
            _sifc.S_BRESP <= 3'b001;
            _sifc.S_BVALID <= 1;
        end
    
        //read addr channel 
        if(_sifc.S_ARREADY && _sifc.M_ARVALID) begin
            rd_addr <= _sifc.M_ARADDR;
            _sifc.S_RVALID <= 1;
            _sifc.S_RDATA <= register[rd_addr];
        end
        //read response channel
        if(_sifc.S_RVALID && _sifc.M_RREADY) begin //if the handshak is done
            _sifc.S_RRESP <= 3'b001; //OKAY response
            _sifc.S_RVALID <= 0; //deassert valid after read
        end
      end
    end
         
  end
    
endmodule


module AXI_top #
( parameter AXI_WIDTH = 64,
  parameter AXI_ADDR_WIDTH = 6,
  parameter AXI_RESP_WIDTH = 3
)
( AXIL_Interface _ifc);

  AXI_lite_slave slave(_ifc.slave);
  
  AXI_lite_master master(_ifc.master);

 endmodule
 
 interface AXIL_Interface #(parameter AXI_WIDTH = 64,
                            parameter AXI_ADDR_WIDTH = 6, parameter AXI_RESP_WIDTH = 3)
 (input clk);
	
   //for AXI_top and AXI_lite_master
  logic rst;
  logic writeEn;
  logic readEn;
  logic [AXI_ADDR_WIDTH-1:0] wr_addr;
  logic [AXI_ADDR_WIDTH-1:0] rd_addr;
  logic [AXI_WIDTH-1:0] data;
        
	//connecting ports
    
  //write request channel
  logic  M_AWVALID;
  logic  S_AWREADY;
  logic  [AXI_ADDR_WIDTH-1:0]M_AWADDR;
  
  //write data channel 
  logic M_WVALID;
  logic S_WREADY;
  logic [AXI_WIDTH-1:0] M_WDATA;
  logic M_WLAST;
  
  //write response channel 
  logic S_BVALID;
  logic M_BREADY;
  logic [AXI_RESP_WIDTH-1:0] S_BRESP;
  
  //read request channel 
  logic M_ARVALID;
  logic S_ARREADY;
  logic [AXI_ADDR_WIDTH-1:0]M_ARADDR;
  
  //read data channel
  logic S_RVALID;
  logic M_RREADY;
  logic [AXI_WIDTH-1:0] S_RDATA;
  logic S_RLAST;
  logic [AXI_RESP_WIDTH-1:0] S_RRESP;
   	
  logic [AXI_WIDTH-1:0] readData;
   
  modport master (input clk, rst, wr_addr, rd_addr, writeEn, readEn, data, S_AWREADY, S_WREADY, S_BVALID, S_BRESP, S_ARREADY, S_RVALID, S_RDATA, S_RRESP, S_RLAST, output M_AWVALID, M_AWADDR, M_WVALID, M_WDATA, M_WLAST, M_BREADY, M_ARVALID, M_ARADDR, M_RREADY, readData);
   
  modport slave (input clk, rst, M_AWVALID, M_AWADDR, M_WVALID, M_WDATA, M_WLAST, M_BREADY, M_ARVALID, M_ARADDR, M_RREADY, output S_AWREADY, S_WREADY, S_BVALID, S_BRESP, S_ARREADY, S_RVALID, S_RDATA, S_RLAST,S_RRESP);
   
   
 endinterface