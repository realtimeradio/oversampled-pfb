
# 

3 different ways to try and do the same thing.

I am trying to figure out the methodology for my data type that I want to adopt
through the rest of my ospfb development.

To be honest I like how slick the first one is. Everything is contained within
the interface to be referenced as localparams. But with an interface it may
prove to be difficult to interface with verilog. This is the only one that also
gets the output data format right as a packed array (like a reg type in plain
old verilog). I can display it as %X or %p. In both cases it matches what the
rfdc would produce.

There is the question though of what is better, packed ram or unpacked? Because
the first one only has data ordering right with packed variables. If we go
unpacked we will need to do some data reordering. Possibly following what was
done in `cmpx4.sv` I hear streaming operators may be what I want?? Store as a
unpacked ram then convert to packed for the port.

Now that I think more about it the RAM where the word width is `pkt_t` is better
for synthesis because I can imagine that being a really slow circuit if the
synthesis tool takes me at my word and does multiple reads out of A BRAM. In the
case of a LUTRAM or registers it may not matter much...

However I have doubts about the RAM variable and if it will actually be able to
be a ram for something larger than 16.

Then there are the other three.

The second is like a mix of one and two. Uses interface but then declares the
`cx_t` inside the modulse. This one does not work as it gets the data ordering
on the output wrong. We need Hi:Lo newest to oldest, i.e., 3,2,1,0, not 0,1,2,3.
However, that can be fixed by just thinking through the data assignment more.

The third removes interfaces. Uses more typedefs and a paramterized data type.
Specifically packed type for the `cx_t` and then unpacked `pkt_t` and a ram of
`pkt_t`. In this one the RAM is the ratio `FFT_LEN/SAMP_PER_CLK` with each word
in the ram being `pkt_t` long. To get the data ordeding right note that the
initial block is a little more involved to set the right values. I hate how I
had to pass in the `SAMP_PER_CLK` value.

Then the fourth one does the same things as the third except it uses all packed
types. Setting the initial values was straight forward but the assigning out to
tdata is where it is the complicated variable slice. This one also needs to pass
in the `SAMP_PER_CLK` parameter.

Because I am afraid something may happen if I don't propagate the right
parameter somewhere like I had in trying to syntheize 3 and the package
`SAMP_PER_CLK` was different than the module parameter default.

I really don't know which I should choose.... Without having got anything to run
in the hardware it is making me so anxious about choosing the correct thing and
then having to back pedal.

I also have my doubts that this method is the right way to go period. Because
for an impulse generator having a ram with zeros except in one location is
wasteful. However with accepting only one sample per clock I am not sure how we
would use a counter to insert the right value without running the counter 2x, or
4x as fast.

But if I really am into systemverilog and so far as long as I have stayed within
system verilog my synthesis seems to work out. If I just stay pure hdl and stay
in system verilog than I should be OK.... Only when I get to things like MPSoC
and block designs will I be in trouble... but even then. I may be able to do SV
wrappers around my block design verilog wrappers and use the `.*` connection notation.

I could even go pure IP catalog route. Then I will need to learn how to do
presets for things like the MPSoC.


Now I have `v1_5` and `cmpx5`.... all super slight variants of each other...
how am I going to keep this straight..

but I am pretty convinced streaming operator can be helpful now given that
vivado synthesis can handle it and I understand how it works (e.g., left << or
right >>). But again this all depends on if memories and ports should differ
between packed and unpacked...

`streaming.sv`
I learned about the streaming operator and saw that there is an opeartor that I
can get the bits reversed. I then decided to build a quick module that did that
operation as it should prove useful when doing the FFT. The module works in
simulation.

This one passed synthesis although I don't really see anywhere in the synthesis
report the logic needed to do that. It seemed that the synthesis report only had
the regsiters. So this is one of those where I wonder if getting it on the FPGA
will be when I can tell if simulation matches synthesis.

I also learned though that the streaming operator is how you can get an unpacked
array assigned to a packed array.

`cmpx5.sv`
Now knowing that unpacked arrays can be assigned to packed with the streaming
operator I took the idea of having an unpacked memory RAM like in `cmpx4.sv` but
also have the packed port of `SAMP_PER_CLK` `cx_t` samples as a packed packet.
The unpacked dimension of the RAM is that we have a memory depth of
`FFT_LEN/SAMP_PER_CLK`. This way we are only accessing one RAM address per clk.
Then on the ouptut we use the new streaming operator to pack the unpacked ram
value to the packede port value.

The interesting thing here is that compared to `cmpx3.sv` I didn't have to have
the funky counter calculation on initializing the memory. The streaming operator
put in the right order for me.

This one passed synthesis.

`cmpx_v1_5.sv`
I took this again to the next step by revisiting `cmpx.sv` (really `cmpx1.sv`)
which used both a packed port and packed RAM variable. In this new one I
switched out the packed racm for an unpacked RAM variable with the same memory
depth of `FFT_LEN/SAMP_PER_CLK` (as I am pretty sure the better thing to do
would to be always store a single packet worth in the RAM to mitigate the number
of reads out a BRAM would have to do).

This one also passed synthesis.

# Asking Google about unpacked/packed ports
In asking Google the question: systemverilog ports packed or unpacked, I ran
into this answer on SO... It seems like it is good advice... And I feel like I
have always agreed with it and really what I am wanting to accomplish here I
should dwell on it and see if this is my same intuition.

There is another reason why I like to use unpacked. With unpacked, there is no
temptation (and accidental possibility) of treating the whole array name as a
variable, and make an erroneous assignment. There is also no possibility of
bit-bleeding from one element to another, when you may be thinking you are
accessing B bits of element N, but in reality you may be accessing K bits of
element N and B-K bits of element N+-1..

My philosophy is to keep only the things that belong together as a "unit of
information" in the packed dimension. Everything else in the unpacked dimension.
The default thinking should be unpacked, and pack only what you need to.

For example, if I have 9 ports, each with 21 bits of information, I would like
to declare it as :
```
input logic [20:0] p1 [9];
```
The 20:0 part constitutes a unit of information, assigned and sampled together
(nominally). Splitting those bits apart will destroy the protocol or the
character of the port. On the other hand, changing the number of ports from 9
to, say, 16, is not going to affect the nature of the information in each port,
so the 9 ports really belong in the unpacked dimension in my mind.

Hope that might give you a paradigm to think along... In this paradigm, you
would be surprised how many things start to appear unpacked that you always
thought were packed.

# where to go from here
I was all ready to go into what `cmpx_v1_5` does. But then I realized I perhaps
don't want to break the rest of my ospfb axis code. Becasue only on the output
of the ADC does the interface look like what is done in `axis_rfdc`. In the
polyphase FIR for example I now need two re or two im samples together.

So this got me thinking about having an axis interface that does a parameterized
dtype.  Or I can have different axis interfaces. Like an `axis_rfdc`,
`axis_ospfb`. But this may be cumbersome. Instead just have different defined
structs and datatypes.

But all this typedef stuff and streaming operators in a weird way has me
interested in writing the alpaca packetizer.

# 09/08/2020
But so today I am feeling a little bit less excited about using the
data type parameterized interface for system verilog and synthesis. Primarily
because when it gets time for synthesis of system verilog modules if the tool
has to guess on what parameters to use it will use the default parameters and
with different types passing through interfaces here (`sample_t`, `cx_t` and
`cx_packet_t`) I can imagine this could be an even worse thing to debug in
hardware if something doesn't get instantiatied right.

Also, you don't know the type of the port just by looking at it...

Also learned today that `$bits` function is understood by vivado syntehsis as it
correctly set a localparam when trying to figure out the width of my packed
struct. `localparam width = $bits(dtype)`

# 09/17/2020
One of the problem with data types is that Vivado synthesis would warn that the
readmemh task was malformed and that 'twiddle' was an 'invalid memory name'.
Therefore in the context of memory Vivado cannot recognize that a packed struct
is just a vector of bits. Adding the $bits() call was enough to help vivado
out... (e.g. `logic signed [$bits(wk_t)-1:0] twiddle [FFT_LEN/2]`) this is a
bug... no reason vivado shouldn't be able to understand this.  But this is one
of those sutble things that argues for widths to be passed around as
parameters...

Also, considering this the importance of they keyword signed in the ROM
inference raises a question. Because I was actually first doing simulations
without it being labled signed and everything was coming out fine. However, I am
not sure what would have happned in hardwre. I therefore changed it to
explicitly say signed. But again this argues you can't do much by defining a
type as signedin one spot and just have it propagate without to again have to
explicitly declare something as signed.

Also, with interfaces it is seemingly annoying to read the synthesis report and
determin if the "unconnected port" warnings are because I missed something or if
because something in the protocol wasn't implemented. This seems to be in favor
of not using interfaces and verbosly declaring the ports. Then instead use the
system verilog `.*` to shorten making all the connections. However, as long as
you read them and go through the report and can convince yourself they aren't
used and won't be a problem it isn't that big a deal.

I think the right thing to do is just have more interfaces defined that covers
all of our different types. It is verbose and descriptive. Work up front but
overall helpful.

But I did learn that with Vivado Synthesis you can define modports that exclude
some of the defined signals and the synthesis tool doesn't complain about it.
That could be helpful in my case. Requires more interface definitions though.

# 09/21/2020
I didn't look at this HDL over the weekend. However, I tried to pick up where I
left off above in the last paragraph stating that I had a standalone interface
testbench that claimed that modports could be used to exclude signals. This
worked in that standalone example (`playground/tmp_if` directory) but then when
applied to my `parallel_xfft` work I didn't see the same effect in Vivado
synthesis. The tool continued to complain about undriven and unconnected nets.
So I am back at thinking several independently defined interfaces is the best
way to go here.
