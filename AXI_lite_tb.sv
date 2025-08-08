// Code your testbench here
// or browse Examples
`timescale 1ns / 1ps

class transaction;

rand bit [63:0] data;
bit             startRead;
bit             startWrite;
bit [5:0]       rd_addr;
bit [5:0]       wr_addr;
bit [63:0]      rd_data;

  function rd_display();
    $display("at time = %0t the data read by the master at read addr: %h is: %h",$time,rd_addr, rd_data); 
  endfunction
  
  function wr_display();
    $display("at time = %0t the data written by the master at wr_addr: %h is: %h",$time, wr_addr, data);
  endfunction
  
endclass

class generator;
    
    mailbox drv_mbx;
    event wr_done;
  	event rd_done;
    
    int num = 10;
    task run();
        transaction item;
        for (int i=0;i<num;i++)begin
            item = new;
            item.randomize();
            drv_mbx.put(item);
          	$display("done generating data: %h",item.data);
          	@(wr_done);
        end
                
    endtask
    
endclass

class driver;
    
    mailbox drv_mbx;
    event wr_done;
  	event rd_done;
    
    virtual AXIL_Interface _ifc;
    
    task run();
        int num = 10;

//        bit [5:0] addr = 0;
        transaction item;
        for(int i=0;i<num;i++) begin
            item = new;
            drv_mbx.get(item);
            _ifc.writeEn <= 1;
            _ifc.wr_addr <= i;
            _ifc.data <= item.data;
          	@(posedge _ifc.clk); //wait for the data to be flopped
           ->wr_done;
        end
      	_ifc.writeEn = 0;
        $display("done writing the data");
      
        //start reading 
        for(int i=0;i<num;i++) begin
            item = new;
            drv_mbx.get(item);
            _ifc.readEn <= 1;
            _ifc.rd_addr <= i;
          	@(posedge _ifc.clk);
          	@(posedge _ifc.clk); //wait 2 clock cycles for the transaction to finish
          	->rd_done;
        end
      	_ifc.readEn <= 0;
      
    endtask
    
endclass

class monitor;
    
    mailbox scb_mbx;
    virtual AXIL_Interface _ifc;
    
    task run();
    
        transaction item;
        forever begin
            item = new;
            item.data = _ifc.data;
            item.wr_addr = _ifc.wr_addr;
            item.rd_addr = _ifc.rd_addr;
            item.rd_data = _ifc.readData;
            scb_mbx.put(item);
        end
        
    endtask
    
endclass

class scoreboard;
    
    mailbox scb_mbx;
 
    task run();
    

      fork 
        forever begin
          transaction item1;
          item1 = new;
          scb_mbx.get(item1);
          item1.wr_display();
        end
        
        forever begin
          transaction item2;
          item2 = new;
          scb_mbx.get(item2);
          item2.rd_display();
        end
        
      join_none
    
    endtask
    
endclass

class environment ;
    
    generator g0;
    driver d0;
    monitor m0;
    scoreboard scb;
    mailbox drv_mbx;
    mailbox scb_mbx;
    event wr_done;
  	event rd_done;
    
    virtual AXIL_Interface _ifc;
    
    function new ();
        
        g0 = new;
        d0 = new;
        m0 = new;
        scb = new;
      	drv_mbx =  new;
      	scb_mbx = new;
        
    endfunction

    virtual task run();
    //creating and assigning virtual interface 
        d0._ifc = _ifc;
        m0._ifc = _ifc;
        
    //creating and assigning mailboxes
        d0.drv_mbx = drv_mbx;
        g0.drv_mbx = drv_mbx;
        m0.scb_mbx = scb_mbx;
        scb.scb_mbx = scb_mbx;
        
     //creating and assigning events
        d0.wr_done = wr_done;
        g0.wr_done = wr_done;
      	d0.rd_done = rd_done;
        g0.rd_done = rd_done;
      
        
        //running tasks inside each class 
        fork 
        g0.run();
        d0.run();
        m0.run();
        scb.run();
        join_any  //spawn all the tasks, wait for generator to finish generating the input stimulus and then leave 
        
    endtask
         
endclass

class test;

    environment env;
    
    function new ();
        env = new;
    endfunction
    
    task run ();
        fork
           env.run();
          $display("run task from the environment");
        join_none
    endtask 

endclass

module tb_top;

    bit clk;
    
    AXIL_Interface _ifc(clk);
    AXI_top DUT(_ifc);

    always #10 clk = ~clk;
    
    test t0;
    initial begin
        
        clk = 0;
        _ifc.rst = 1;
        #20
        _ifc.rst = 0;
        
        t0 = new();
        t0.env._ifc = _ifc;
       
        $display("run task in test");
        fork 
           t0.run();
        join
      	
      	$finish;
         
    end
    
endmodule
