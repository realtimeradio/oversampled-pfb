`default_nettype none

package alpaca_ospfb_ix_pkg;

// TODO: food for thought on making more abstract, templated probes...
//virtual class poker #(type T);
//  pure virtual function T getter();
//endclass

virtual class probe #(parameter WIDTH, parameter DEPTH);
  pure virtual function string peek();
  pure virtual function string poke();
  //pure virtual function logic[DEPTH*WIDTH-1:0]  get_sr();
endclass

virtual class vpe;
  pure virtual function string peek(int idx, int fft_len);
endclass

//virtual class vsrc;
//  pure virtual function string peek();
//  pure virtual function int get_frameCtr();
//  pure virtual task run();
//endclass

//virtual class template_probe #(parameter WIDTH, type T=logic[WIDTH-1:0]);
//  pure virtual function string poke();
//endclass

/*
  Note: Virtual classes only need pure virtual methods declared if something is going to call
  a method on the the virtual typed class. Otherwise a class could extend the virtual function
  definitions. This means if there was a way to abstract out methods in the class to just
  have their implementatio lead to calling the peek or poke method and have generally universal
  parameter definitions then this could reduce the required virtual class definitions

  e.g., for probe, get_sr could be commented out and work because of how sr_probe works
*/

endpackage
