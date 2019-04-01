function [Z, Yi] = pfb4os(Y,L_f,L_c,l1,Yi)
%%% Special second stage fine PFB version for fixing scolloping.  
%  note that here we use a simple FFT rather than full PFB since it is
%  unnecessary to have a true PFB in the second stage to observe
%  scolloping. 
%  Do not implement this in the GPU as coded here, other than
%  you must have the same number of frequency channels,, and you
%  must discard the the same number of lower, and serparately, the same 
%  number of upper output channels as done here.
%
% Brian D. Jeffs  7/19/17

% Brian D. Jeffs  11/20/18: Modified to handle different decimations rates
% than L_c, so that we can implement oversampled polyphase filter banks.
%
% Y:   Coarse channelized data, size: N/Dec by L_c. N: no. of original time
%      samples in this data block
% L_f: Number of fine channels returned per coarse channel (not the FFT size)
% L_c: Number of coarse channels
% l1:  Half width (in channels) of the retained (non-overlapped) fine channels
% Z:   Output fine channelized data array, size L_f by N_s by L_c.  N_s is
%      specified in oversampPFB_2stage.m

% this is the index to the last fine bin retained for the spectrometer.  The 
%  rest are discarded as overlapping, as are the corresponding first few bins
last_bin = l1 + L_f/2 + 1;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Separate coarse channelized data into time series blocks of length L_f
% and then pass these through the fine filter bank (just an FFT here).

Ya = [Yi;Y];                      % Prepend unused data from last window call
K = floor(size(Ya,1)/L_f);   % No. of fine FFTs we can compute per coarse chan. 
                                  % given the no. of time samples in Ya                                 
YY = reshape(Ya(1:K*L_f,:),L_f,K,L_c); 

Z2 = fftshift(fft(YY),1);

% extract and return just the non-overlapped fine channelized freq. bins
Z = Z2(last_bin-2*l1+1:last_bin,:,:); 

% Save the last few samples across coarse chans which we could not use because 
%  we did not have enough to complete a full fine pfb per coarse chan.
Yi = Ya(K*L_f+1:end,:);

end