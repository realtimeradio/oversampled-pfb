# Temporary Coefficient Files for Test Repeatability

These coeffecients are generated for `M=64, D=48, P=3` and tracked to be able
to repeat tests bringing the OSPFB up and back to a known working state.

In the case of `cycramp` these are so we can get back to testing the oversampled
FIR + phasecomp output prior to the FFT with the python counter.

The `ones/` are rect window coefficients at a low scale that were able to show
that the OSPFB is at least working but that we have overflow effects.
 
