function [Y, Xf] = pfb1(x,L_c,H,Xi)

% Coarse polyphase filter bank
%
% Brian D. Jeffs  7/18/17

P = size(H,2);                  % number of taps per polyphase filter branch
X = reshape(x,L_c,[]);          % Implements the PFB delay line, and decimation
Nd = size(X,2);                 % number of new decimated time samples per polyphase filter branch
Xa = [Xi,X];                    % append filter state memory

% Actual polyphase filtering comvolution per decimated time sample index, 
% i, across all polyphase branches
XX = zeros(L_c,Nd);
for i = 1:Nd
    XX(:,i) = sum(H.*Xa(:,i:i+P-1),2);
end

% The fft now sums each polyphase branch, with bandshift mixing to create
% L_c coarse channels
Y = fftshift(fft(XX),1).';

Xf = X(:,Nd-P+2:Nd);            % Save filter shift register state for next block

end
