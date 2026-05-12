% VERIFY_SYNTHETIC  End-to-end self-test on a known 2nd-order plant.
%
% Generates a chirp + small noise input, simulates a known system
%   H_true(s) = K * wn^2 / (s^2 + 2*zeta*wn*s + wn^2)
% with K=1.5, wn=2*pi*3, zeta=0.25, then runs the full sysid pipeline and
% checks that the recovered (K, wn, zeta) match within a few percent and
% that VAF on held-out data is > 95%.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));

% --- Truth ---
K_true    = 1.5;
fn_true   = 3.0;          % Hz
zeta_true = 0.25;
wn_true   = 2*pi*fn_true;
num_true = K_true*wn_true^2;
den_true = [1, 2*zeta_true*wn_true, wn_true^2];

% --- Excitation: 0.1..10 Hz chirp + small noise ---
fs = 200; T = 60; t = (0:1/fs:T-1/fs)';
u = chirp(t, 0.1, T, 10, 'logarithmic');
u = u + 0.02*randn(size(u));

% --- Simulate + add measurement noise ---
y_clean = sysid.sim_ct(num_true, den_true, u, fs);
y = y_clean + 0.01*std(y_clean)*randn(size(y_clean));

% --- Wrap into a "preprocessed" struct shape that the pipeline expects ---
pre = struct('t',t,'fs',fs,'roles',{{'u','y'}}, 'u', u, 'y', y);

% --- FRF + fit (skip CSV/preprocess; we already have clean signals) ---
N_tr = round(0.5*numel(t));
u_tr = u(1:N_tr); y_tr = y(1:N_tr);
u_va = u(N_tr+1:end); y_va = y(N_tr+1:end);
t_va = (0:numel(u_va)-1)'/fs;

frf = sysid.frf_welch(u_tr, y_tr, fs, ...
        struct('nfft',2048,'overlap',0.5,'fmin',0.1,'fmax',20));
fit = sysid.fit_param_tf(frf, struct('order',2,'fmin',0.1,'fmax',20));

K_fit = fit.params(1); wn_fit = fit.params(2); zeta_fit = fit.params(3);
fprintf('\n--- Truth vs Fit ---\n');
fprintf('  K     truth=%.3f  fit=%.3f  err=%+5.2f%%\n', K_true, K_fit, 100*(K_fit-K_true)/K_true);
fprintf('  fn    truth=%.3f  fit=%.3f  err=%+5.2f%%\n', fn_true, wn_fit/(2*pi), 100*(wn_fit/(2*pi)-fn_true)/fn_true);
fprintf('  zeta  truth=%.3f  fit=%.3f  err=%+5.2f%%\n', zeta_true, zeta_fit, 100*(zeta_fit-zeta_true)/zeta_true);

% --- Validation ---
y_pred_va = sysid.sim_ct(fit.num, fit.den, u_va, fs);
vaf_va    = sysid.score_vaf(y_va, y_pred_va);
fprintf('  VAF (validation) = %.2f%%\n', vaf_va);

% --- Impulse response ---
ir = sysid.impulse_svd(u_tr, y_tr, fs, struct('L',round(2*fs),'sv_keep',0.95));
fprintf('  Static gain from IR = %.3f (truth K = %.3f)\n', ir.gain_dc, K_true);

% --- Plot ---
overlay = struct('f',frf.f,'H',fit.H_pred);
sysid.plot_bode(frf, 'Title','Synthetic verify', ...
    'OverlayFRF',overlay, 'OverlayLabel','LM fit');

figure('Color','w'); plot(t_va, y_va, '-', t_va, y_pred_va, '--', 'LineWidth',1.2);
grid on; legend('measured','predicted'); xlabel('time (s)');
title(sprintf('Synthetic validation: VAF=%.2f%%', vaf_va));

% --- Pass/fail ---
ok =  abs(K_fit-K_true)/K_true     < 0.05 ...
   && abs(wn_fit-wn_true)/wn_true  < 0.05 ...
   && abs(zeta_fit-zeta_true)/zeta_true < 0.10 ...
   && vaf_va > 95;
if ok
    fprintf('\nVERIFY OK — toolbox recovers the known system within tolerance.\n');
else
    warning('VERIFY: out of tolerance — inspect plots and fit_param_tf init.');
end
