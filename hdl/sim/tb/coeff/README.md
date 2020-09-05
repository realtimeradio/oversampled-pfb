# Temporary Coefficient Files for Test Repeatability

This coefficient structure is only supported in the first version of the OSPFB
that only used SRL shift registers for the delay chain.

These coeffecients and tracked in order to repeat tests with the OSPFB
quickly and bring it back to a known state.

The general format of a coeff file name is: `h_{pe_idx}_{M}_{P}_{bits}.coeff`
where `M` and `P` are the OSPFB configuration parameter FFT lenght and polyphase
taps, respectively. `pe_idx` is the corresponding PE in the design `0 <= pe_idx
< P` and `bits` represent the quantization level of the taps.

In the case of `cycramp` these are so we can get back to testing the oversampled
FIR + phasecomp output prior to the FFT with the python counter. There is a
single file and each PE is loaded with the sample samples. This file will work
for `M` up to 2048. The `$readmemh()` call will just warn that the file is
larger than the memory and fill the memory up.

The `ones/` are rect window coefficients at a low scale that were able to show
that the OSPFB is at least working but that we have overflow effects.
 
