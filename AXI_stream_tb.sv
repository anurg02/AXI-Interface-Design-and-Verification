// Code your testbench here
// or browse Examples

`timescale 1ns/1ns 
class axi_item;
  
  rand byte TDATA;  //data in bytes
  bit 		TVALID;
  bit 		TLAST;
  bit      t_done;
  bit      TREADY;
  
  function display ();
    $display("Data packet and control informatio for this transaction");
    $display("TDATA is : %h, TVALID is : %b, TLAST is : %b, t_done is : %b", TDATA,TVALID,TLAST,t_done);
  endfunction
  
endclass

class generator;
  
  mailbox drv_mbx;  //mailbox connecting to driver mailbox
  int num = 10;
  event drv_done;
  
  task run();
    
    axi_item item; //transaction object for every transaction
    for (int i=0;i<num;i++) begin
      item = new;
      item.TLAST = 0;
      item.randomize(); //assertion that TLAST should be 0 
      
      $display("the transaction data at %d transaction is TDATA = %h, TVALID =%b, TLAST = %b",i,item.TDATA,item.TVALID,item.TLAST);
      drv_mbx.put(item);
      @(drv_done); //wait till the driver drives this data packet before transmitting a new one
    end
    item = new;
    item.TLAST = 1;
    item.randomize();
    $display("sending the last transaction");
    drv_mbx.put(item);
    @(drv_done); //wait until the driver accepts and drives the last data item 
    
  endtask

endclass
  
class driver;
  
  virtual axiInterface vifc;
  mailbox drv_mbx;
  event drv_done;

  
  task run(); //to drive the interface signals with the data packet 
    
    $display("T=%0t starting the driver to drive ifc signals",$time);
    //wait for a posedge clk 
    @(posedge vifc.clk);
    
    forever begin
        axi_item item;
      	drv_mbx.get(item);
      	
      	vifc.TVALID <= 1;
      	vifc.TDATA  <= item.TDATA;
     	vifc.TLAST  <= item.TLAST;
        @(posedge vifc.clk)  //wait for the data to be latched at the posedge
      while (!vifc.TREADY) begin
        $display("waiting for TREADY");
        @(posedge vifc.clk);//wait for the ready signal to be high with posedge clk
      end
      	$display("transaction complete");
        vifc.TVALID <= 0;
        ->drv_done;
    end
    
  endtask
  
endclass


class monitor;
  
  virtual axiInterface vifc;
  mailbox scb_mbx;
  
  task run();
    $display("started the monitor: ");
    
    forever begin
      @(posedge vifc.clk);

      if(vifc.TVALID) begin   //if there exists a valid transaction
      	axi_item item;
        item = new;
        item.TREADY =  vifc.TREADY; 
        item.t_done = vifc.Tdone;
        item.TDATA = vifc.TDATA;
        scb_mbx.put(item);
        $display("monitored object members: %h %h %h", vifc.TREADY, vifc.Tdone, vifc.TDATA);
      end
       
    end
    
  endtask
  
endclass

class scoreboard;
  
  mailbox scb_mbx;

  task run ();
    $display("scoreboard to display DUT outputs");
    forever begin
      axi_item item; 
      scb_mbx.get(item);
      item.display();
    end
    
  endtask
endclass

class environment;
  
  generator g0;
  driver d0;
  monitor m0;
  scoreboard scb;
  
  mailbox drv_mbx;
  mailbox scb_mbx;
  
  event drv_done;
  
  virtual axiInterface vif;
  
  function new ();
    g0 = new;
    d0 = new;
    m0 = new;
    scb = new;
    drv_mbx = new;
    scb_mbx = new;
  endfunction
  
virtual task run();
    
    //connnect mailboxes
    d0.drv_mbx = drv_mbx;
    g0.drv_mbx = drv_mbx;
    m0.scb_mbx = scb_mbx;
    scb.scb_mbx = scb_mbx;
    
    //connect virtual interfaces to be instantiated from the top
    d0.vifc = vif;
    m0.vifc = vif;
  
  	g0.drv_done = d0.drv_done;
    
   	//call all the run tasks sequentially 
  fork
    g0.run();  // wait for the generation to complete before leaving the context
    d0.run();
    m0.run();
    scb.run();
  join_any
     
  endtask
    
endclass

class test;
  
  environment e0;
  
  function new ();
    e0 = new;
  endfunction
  
  virtual task run();
    
    fork
      e0.run();
    join
    
  endtask 
  
endclass
    

module tb_top();
    
  logic clk;
  
  axiInterface _ifc(clk);
  axis_slave DUT(_ifc.slave);
  
  test t0;

  always #10 clk = ~clk;
  

  initial begin

    clk <= 0;
  	_ifc.reset <= 1;
    #20 
    _ifc.reset <= 0;
  
	t0 = new;
    t0.e0.vif = _ifc;  //pass the actual interface 
    fork
    	t0.run();
    join
    
    $finish;
    
  end
    
endmodule
  