% Determine expected bin and frequency

% TODO: consider as a unit test case a way to sweep through bins and check
% to make sure the correct power is present in each bin.

M = 32;                           % Transform size (i.e., polyphase branches, Nfft_coarse)
D = 24;                           % Decimation rate (D < M)

Nfft_coarse = M;                  % Transform size for 1st stage PFB (number of channels from 1st stage)
Nfft_fine = 512;                  % Each corase PFB is channelized by Nfft for second stage zoom

N_channels = D*Nfft_fine;         % Total number of channels in a 2nd stage following an oversampled PFB.
                                  % Note that a second stage following a critically sampled PFB would have
                                  % M*Nfft_fine channels. However you would never follow a critically sampled PFB
                                  % with another PFB because you would havethe scalloping and alias problems.

fs = 10e3;                        % signal sampling rate (Hz)
fs_cs = fs/M;                     % critically sampled PFB output time-series sample rate (Hz)
fs_os = fs/D;                     % Oversampled PFB output time-series sample rate (Hz)

fine_bin_width = fs_os/Nfft_fine; % bin width of fine spectrum (Hz/bin)

fbins_coarse = 0:M-1;           
faxis_coarse = fbins_coarse*fs/M;

fbins_fine = 0:N_channels-1;
faxis_fine = fbins_fine*fs_os/Nfft_fine;

f_soi = 1250;
expected_bin = calcBinLoc(f_soi, fine_bin_width);

bin_number = 6300;
f = FsoiFromBinNumber(bin_number, fine_bin_width);

function bin_number = calcBinLoc(f_soi, bin_width)
% Can return a non integer number. Fractions of a bin numbers mean the tone
% will be split between adjacent bins.

% does not check bounds (a requested frequency will not roll over)

  bin_number = f_soi/bin_width;
  
end

function f_soi = FsoiFromBinNumber(bin_number, bin_width)
% can accept fraction of bin numbers

% does not check bounds (able to return a bin number greater than possible)

  f_soi = bin_number*bin_width;
end
