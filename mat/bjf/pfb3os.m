function [Y,xi,m_samp] = pfb3os(x,L_c,H,xi,m_samp,Dec)
% Coarse oversampled polyphase filter bank
%
% Brian D. Jeffs  7/18/17
% 11/20/18:  Modified to do an oversampled PFB which can handle 
% different decimations rates than L_c, so that we can implement 
% oversampled polyphase filter banks.
%
% x:   Input data sample vector, complex
% L_c: Number of coarse frequency channels
% H:   Polyphse filter coefficients. size: L_c x P. Each row contains the
%      tap weights for a single PFB branch filter.
% Xi:  Input:Filter state values from last call to pfb3os. Output: state at
%      end of this call
% ls:  >= 0, < Dec, % "last sample" index for how far we got (in last call 
%      to pfb3os.m) towards computing Dec undecimated ouput samples
%      in order to get the next decimated value for Y.
%      This keeps track of decimation index between data
%      blocks which may not be multiples of Dec in length             
% Dec: Decimation rate for this coarse PFB. D <= L_c
% k:   PFB circular shift index between filter branches and FFT
% Y:   Coarse channelized data output, size: N/Dec by L_c. 
%      N: no. of original time samples in this data block
% m_samp: decimated sample index (can be reduced modulo L_c)
%      used to keep track of circular shift state in
%      pfb3os. A running count is needed across windows.


P = size(H,2);           % number of taps per polyphase filter branch
xa = [xi;x];             % Prepend holdover samples from last window
N = length(xa);
Nd = floor((N-P*L_c)/Dec);       % Number of decimations we can do in our data window
% if (Nd-1)*Dec + L_c > N  % If can't fit in the last oversamp circ shift, then
%     Nd = Nd - 1;
% end
                                
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Oversampled PFB kernel:
% i is decimated time sample index. Branch filter state memory is formed
% from a sliding (length P*L_c) window of input data vector x.

for i = 1:Nd
    n_1 = (i-1)*Dec + 1;        % starting sample index in shift reg. for filter 
                                %  state memory to compute next decimated output
                                
    Xa = reshape(xa(n_1:n_1+L_c*P-1),L_c,P);  % Select the register values within
                                %  the sliding window. Note that xa(n_1:n_1+L_c*P-1)
                                %  is the window of the innput data vector which
                                %  lies within the shift register when computing 
                                %  the next decimated filter output sample 
                                %  across the polyphase filter branches

    branchSums = sum(H.*Xa,2);  % Compute PFB branch filter outputs
    
    % Now circularly shift the PFB branch outputs to correct frequency shift
    % caused by non-critical sampling (i.e. decimating by Dec rather than L_c).
    k = mod((i-1+m_samp)*Dec,L_c);   % Calc. circular shift amount. In FPGA this 
                                     % is a table look up with only a few states
                                     % i.e. only a few values of k are valid
    XXcirc(:,i) = circshift(branchSums,k); % barrel shifter to rotate filter bank bins
end

% The fft now sums each polyphase branch while applying bandshift mixing to create
% L_c coarse channels
Y = fftshift(fft(XXcirc),1).';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% What follows is not right and needs work **********
xi = xa(Nd*Dec+1:end);          % Save samples needed for overlap in next window
num_rots = fix(L_c/gcd(L_c,Dec)); % Number of unique circular shift indices, k
m_samp = mod(Nd+m_samp,num_rots);

% Since N may not be a multiple of Dec, keep track of where decimation left
% off and restart on next call at the same point
%ls = mod(N-Dec+ls,Dec);    




end


