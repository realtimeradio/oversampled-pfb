import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

interface axis #(parameter WIDTH) ();
  logic [WIDTH-1:0] tdata;
  logic tvalid, tready;

  modport MST (input tready, output tdata, tvalid);
  modport SLV (input tdata, tvalid, output tready);

  function string print();
    automatic string s = $psprintf("{tvalid: 0b%s, tready:0b%s, tdata:0x%s}",
                                    BINFMT, BINFMT, DATFMT);
    return $psprintf(s, tvalid, tready, tdata);
  endfunction
endinterface

interface alpaca_axis #(parameter type dtype, parameter TUSER) ();

  dtype tdata;
  logic tvalid, tready;
  logic tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

endinterface

/****************************************************
  recent new style interfaces from parallel xfft
*****************************************************/

import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

//interface alpaca_axis #(parameter type dtype=cx_pkt_t, parameter TUSER=8) ();
//  dtype tdata;
//  logic tvalid, tready, tlast;
//  logic [TUSER-1:0] tuser;
//
//  modport MST (input tready, output tdata, tvalid, tlast, tuser);
//  modport SLV (input tdata, tvalid, tlast, tuser, output tready);
//endinterface

// Xilinx fft interfaces
interface alpaca_xfft_status_axis #(parameter type dtype = logic [FFT_STAT_WID-1:0]) ();
  dtype tdata;
  logic tvalid;

  modport MST (output tdata, tvalid);
endinterface : alpaca_xfft_status_axis

interface alpaca_xfft_config_axis #(parameter type dtype = logic [FFT_CONF_WID-1:0]) ();
  dtype tdata;
  logic tvalid, tready;

  modport MST (input tready, output tdata, tvalid);
  modport SLV (input tdata, tvalid, output tready);
endinterface : alpaca_xfft_config_axis

interface alpaca_xfft_data_axis #(
  parameter type dtype = cx_t,
  parameter int TUSER=8
) ();
  dtype tdata;
  logic tvalid, tready, tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

endinterface : alpaca_xfft_data_axis

// parallel sample (and single) capable interface
// note: if working inside system verilog this works OK even with SAMP_PER_CLK=1 but when
// interfacing to a VHDL/Verilog instance this won't work well you have to access the 0th
// element of the data field (e.g., s_axis.tdata[0]) to get the conversion to work

interface alpaca_data_pkt_axis #(
  parameter type dtype = cx_t,
  parameter SAMP_PER_CLK=2,
  parameter TUSER=8
) ();
  // honestly, this seems redundant and superfulous, might as well just keep everything as a
  // global typedef... but then it seems stupid to have parameters and interface in module...
  // this is a real nightmare for me... I feel like this type thing is great but dragging me
  // down
  localparam samp_per_clk = SAMP_PER_CLK;
  typedef dtype [SAMP_PER_CLK-1:0] data_pkt_t;

  data_pkt_t tdata;
  logic tvalid, tready, tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

  function string print();
    automatic string s = $psprintf("{tvalid: 0b%s, tready:0b%s, tdata:0x%s}",
                                    "%0b", "%0b", "%0p");
    return $psprintf(s, tvalid, tready, tdata);
  endfunction

endinterface : alpaca_data_pkt_axis
