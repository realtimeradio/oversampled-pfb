% bank of deimated FIR filters
clearvars;
M = 32;
D = 24;
P=8;

L = M*P;

% Design prototype LPF (Hanning window)
idx = -P/2*(M/D):1/D:(M/D)*P/2-1/D; % (M/D) 1/D to extend to the correct L length. Note: need to design the filter for the decimation rate D not the maximally sampled rate M in fact I really need to investiagate proper filter design here to get a super tight corner to achieve an image rejection as low as askap does of -60dB.
x = sinc(idx);
hann = hanning(L).';
h = x.*hann;

% h = fir1(L-1, 0.95/D,'low',hamming(L));

osratio = M/D;


fs = 10e3;
f_soi = 2000;

Nfft = M;
Nfft_fine = 512;
hsov = (M-D)*Nfft_fine/(2*M);

fine_frames = 10;

X = zeros(Nfft, Nfft_fine);
Xf = zeros(Nfft*Nfft_fine, fine_frames);
Xfpruned = zeros(D*Nfft_fine, fine_frames);

yi = zeros(M,L-1);
n = (0:M-1)';
decmod = 0; % variable to track where to start from in next decimation sequence
nn = 0;
%%
for i=1:fine_frames
  st = 1;
  ed = 1;
  X = zeros(Nfft, Nfft_fine);
  while ed <= Nfft_fine
    % generate a sequence of input data
    argf = (1j*2*pi*f_soi/fs*(nn*M:(nn+1)*M-1)).';
    nn = nn+1;
    sig = exp(argf);
    noise = randn(M,1) + 1j*randn(M,1);
    x = sig + noise;
    
    for k = 1:M
      % mix
      xmix = x.*exp(-1j*2*pi*(k-1)*n/M);
      % lpf
      [ymix, yi(k,:)] = filter(h, 1, xmix, yi(k,:));
      % decimate
      ydec = ymix(1+decmod:D:end);
      % store
      ed = st+length(ydec);
      X(k, st:ed-1) = ydec;
    end
    st = ed;
    decmod = mod(D-M+decmod,D);
  end
  fine = fftshift(fft(X, Nfft_fine,2),2)/Nfft_fine; % also need to fftshift on the 2 dim here...
  fine_pruned = fine(:, hsov:end-hsov-1); % which is it... (hsov+1:end-hsov) or... ... it looks like the current one is correct
  Xf(:, i) = reshape(fine.', [Nfft*Nfft_fine,1]); % the .' on the reshape always gets me...
  Xfpruned(:, i) = reshape(fine_pruned.', [D*Nfft_fine,1]); % the .' on the reshape always gets me...
end
%%

fs_os = fs/D;
fshift = -(Nfft_fine/2-hsov+1);
fbins = (0:M*Nfft_fine-1)*fs/M/Nfft_fine;
fbins_pruned = ((0:D*Nfft_fine-1) + fshift)*fs_os/Nfft_fine;
% 
% figure(1);
% plot(fbins_pruned, 20*log10(abs(Xfpruned(:,1))))
% xlim([min(fbins_pruned), max(fbins_pruned)]);

% figure(2);
% Sxx = mean(abs(Xf).^2,2);
% plot(fbins, 10*log10(Sxx));

figure(3);
Sxx_pruned = mean(real(Xfpruned.*conj(Xfpruned)), 2);
plot(fbins_pruned, 10*log10(Sxx_pruned)); grid on;
xlim([min(fbins_pruned), max(fbins_pruned)]);
% ylim([-20, 70]);
% 
% for m = 1:M
%   figure(4);
%   subplot(4,8,m);
%   fbins_corrected = ((m-1)-1/2)*(Nfft_fine-2*hsov):((m-1)+1/2)*(Nfft_fine-2*hsov)-1;
%   f_corrected = fbins_corrected*fs_os/Nfft_fine;
%   plot(f_corrected, 20*log10(abs(fine_pruned(m,:)))); grid on;
%   xlim([min(f_corrected), max(f_corrected)]);
%   ylim([-60, 40]);
% end
% 
% % faxis not really correct here because it is linear. True faxis would
% % share edges with adjacent axes.
% for m = 1:M
%   figure(5);
%   subplot(4,8,m);
%   fbins_corrected = ((m-1)-1/2)*(Nfft_fine):((m-1)+1/2)*Nfft_fine-1;
%   f_corrected = fbins_corrected*fs_os/Nfft_fine;
%   plot(f_corrected, 20*log10(abs(fine(m,:)))); grid on;
%   xlim([min(f_corrected), max(f_corrected)]);
%   ylim([-60, 40]);
% end
