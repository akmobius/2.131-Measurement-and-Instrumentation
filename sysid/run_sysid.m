% RUN_SYSID  End-to-end system-identification driver for the heart-pump rig.
%
% Edit the USER CONFIG block, then run.  Loads CSV(s), preprocesses, runs
% non-parametric FRF + impulse response, fits a parametric transfer function,
% validates on held-out data, and saves figures + results.
%
% The toolbox lives in the +sysid package next to this script. Add the parent
% folder to the path (or run this script from the parent folder) so MATLAB
% can resolve sysid.<func>.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));

%% ============================ USER CONFIG ===================================
cfg = struct();

% --- Input layout ------------------------------------------------------------
% (A) One file per channel:  set cfg.csv.files + cfg.csv.roles as cellstrs
% (B) One wide CSV:          set cfg.csv.files = {'data.csv'} and
%                            cfg.csv.roles as a struct mapping CSV cols->roles
%
% Example (A):
%   cfg.csv.files = {'piston.csv','air_p.csv','air_q.csv','out_p.csv','out_q.csv'};
%   cfg.csv.roles = {'piston_pos','inlet_air_p','inlet_air_q','outlet_water_p','outlet_water_q'};
%
% Example (B):
%   cfg.csv.files = {'sweep_001.csv'};
%   cfg.csv.roles = struct('time','time', ...
%                          'piston_pos_mm','piston_pos', ...
%                          'air_pressure_kPa','inlet_air_p', ...
%                          'air_flow_LPM','inlet_air_q', ...
%                          'outlet_pressure_kPa','outlet_water_p', ...
%                          'outlet_flow_LPM','outlet_water_q');
cfg.csv.files = {'sweep_001.csv'};
cfg.csv.roles = struct( ...
    'piston_pos_mm','piston_pos', ...
    'inlet_air_pressure','inlet_air_p', ...
    'inlet_air_flow','inlet_air_q', ...
    'outlet_water_pressure','outlet_water_p', ...
    'outlet_water_flow','outlet_water_q');
cfg.csv.time_col = 'time_s';

% --- Resample / preprocess ---------------------------------------------------
cfg.fs            = 200;        % Hz, target uniform rate (Nyquist >> bandwidth of interest)
cfg.preprocess.detrend   = 'mean';
cfg.preprocess.lp_cutoff = 25;  % Hz, zero-phase Butterworth
cfg.preprocess.lp_order  = 4;
cfg.preprocess.notch_f0     = [];   % e.g. 60 if 60 Hz line noise present
cfg.preprocess.trim_sec     = 1.0;  % drop startup transient
cfg.preprocess.trim_end_sec = 0;    % drop trailing samples (e.g. spin-down)

% --- I/O pair to identify ----------------------------------------------------
cfg.input_role  = 'piston_pos';
cfg.output_role = 'outlet_water_q';

% --- Excitation type: 'sine_sweep' | 'broadband' (trapezoid/step/PRBS) ------
cfg.excitation = 'sine_sweep';

% --- Welch FRF ---------------------------------------------------------------
cfg.welch.nfft    = 4096;
cfg.welch.overlap = 0.5;
cfg.welch.fmin    = 0.05;
cfg.welch.fmax    = 25;

% --- Impulse response (SVD) --------------------------------------------------
cfg.ir.L_sec   = 2.0;
cfg.ir.sv_keep = 0.95;

% --- Parametric fit ----------------------------------------------------------
cfg.fit.order  = 2;          % 1, 2, or higher
cfg.fit.weight = 'coh2';

% --- Validation split --------------------------------------------------------
cfg.split_frac = 0.5;        % first half = train, second half = validate

% --- Output ------------------------------------------------------------------
cfg.out_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

%% ============================ PIPELINE ======================================

fprintf('[1/8] Loading CSV(s)...\n');
data = sysid.load_csv(cfg.csv);

fprintf('[2/8] Resampling to %.1f Hz...\n', cfg.fs);
uni  = sysid.resample_uniform(data, cfg.fs);

fprintf('[3/8] Preprocessing (detrend + LPF)...\n');
pre  = sysid.preprocess(uni, cfg.preprocess);

% Pull I/O pair
u_full = pre.(cfg.input_role);
y_full = pre.(cfg.output_role);
t_full = pre.t;
fs     = pre.fs;

% Train/validate split
N_tr = round(cfg.split_frac * numel(t_full));
u_tr = u_full(1:N_tr);  y_tr = y_full(1:N_tr);  t_tr = t_full(1:N_tr);
u_va = u_full(N_tr+1:end);  y_va = y_full(N_tr+1:end);
t_va = t_full(N_tr+1:end) - t_full(N_tr+1);

fprintf('[4/8] Welch FRF (training half)...\n');
welch_opts = struct('nfft',cfg.welch.nfft,'overlap',cfg.welch.overlap, ...
                    'fmin',cfg.welch.fmin,'fmax',cfg.welch.fmax);
frf = sysid.frf_welch(u_tr, y_tr, fs, welch_opts);

dwell_pts = [];
if strcmpi(cfg.excitation, 'sine_sweep')
    fprintf('[4b/8] Detecting sine-sweep dwells + per-dwell DFT...\n');
    segs = sysid.segment_sine_sweep(t_tr, u_tr);
    fprintf('       Found %d dwell segments.\n', numel(segs));
    dwell_pts = sysid.frf_sine_dwell(u_tr, y_tr, fs, segs);
end

fprintf('[5/8] Impulse response via SVD-Toeplitz...\n');
ir_opts = struct('L', round(cfg.ir.L_sec*fs), 'sv_keep', cfg.ir.sv_keep);
ir = sysid.impulse_svd(u_tr, y_tr, fs, ir_opts);
fprintf('       Static gain (sum(h)*dt) = %.4g\n', ir.gain_dc);

fprintf('[6/8] Parametric fit (order = %d, LM)...\n', cfg.fit.order);
fit_opts = struct('order', cfg.fit.order, 'weight', cfg.fit.weight, ...
                  'fmin', cfg.welch.fmin, 'fmax', cfg.welch.fmax);
fit = sysid.fit_param_tf(frf, fit_opts);
fprintf('       Fitted parameters:\n');
for k = 1:numel(fit.params)
    fprintf('         %-6s = %.4g\n', fit.param_names{k}, fit.params(k));
end
fprintf('       Frequency-domain SSE = %.4g\n', fit.resnorm);

fprintf('[7/8] Validating on held-out half...\n');
y_pred_va = sysid.sim_ct(fit.num, fit.den, u_va, fs);
vaf_va    = sysid.score_vaf(y_va, y_pred_va);
aic_va    = sysid.score_aic(y_va - y_pred_va, numel(fit.params));
fprintf('       VAF (validation) = %.2f%%\n', vaf_va);
fprintf('       AIC (validation) = %.2f\n',   aic_va);

fprintf('[8/8] Sensitivity sweep...\n');
sens = sysid.sensitivity(fit, frf, struct('pct',0.20,'npts',21));

%% ============================ PLOTS =========================================

overlay = struct('f', frf.f, 'H', fit.H_pred);
fig1 = sysid.plot_bode(frf, ...
    'Title', sprintf('%s -> %s   (fit order %d, VAF_{val}=%.1f%%)', ...
                     cfg.input_role, cfg.output_role, cfg.fit.order, vaf_va), ...
    'OverlayFRF', overlay, 'OverlayLabel', 'parametric fit', ...
    'DwellPoints', dwell_pts);
exportgraphics(fig1, fullfile(cfg.out_dir, 'bode.png'), 'Resolution', 150);

fig2 = figure('Color','w','Position',[100 100 720 320]);
plot(ir.t, ir.h, 'LineWidth', 1.4); grid on;
xlabel('time (s)'); ylabel('h(t)');
title(sprintf('Impulse response (SVD-Toeplitz), DC gain = %.3g', ir.gain_dc));
exportgraphics(fig2, fullfile(cfg.out_dir, 'impulse.png'), 'Resolution', 150);

fig3 = figure('Color','w','Position',[100 100 900 360]);
plot(t_va, y_va, '-', 'LineWidth', 1.2, 'DisplayName','measured'); hold on; grid on;
plot(t_va, y_pred_va, '--', 'LineWidth', 1.2, 'DisplayName','predicted');
xlabel('time (s)'); ylabel(cfg.output_role, 'Interpreter','none');
title(sprintf('Validation: VAF=%.2f%%   AIC=%.1f', vaf_va, aic_va));
legend('Location','best');
exportgraphics(fig3, fullfile(cfg.out_dir, 'validation.png'), 'Resolution', 150);

fig4 = figure('Color','w','Position',[100 100 240*numel(sens) 320]);
tlS = tiledlayout(fig4, 1, numel(sens), 'TileSpacing','compact','Padding','compact');
for k = 1:numel(sens)
    nexttile; plot(sens(k).values, sens(k).sse, '-o','MarkerSize',4); grid on;
    xlabel(sens(k).name); ylabel('SSE');
    xline(sens(k).center, '--');
end
title(tlS, 'Parametric sensitivity (\pm20%)');
exportgraphics(fig4, fullfile(cfg.out_dir, 'sensitivity.png'), 'Resolution', 150);

%% ============================ SAVE ==========================================
results = struct('cfg',cfg,'frf',frf,'ir',ir,'fit',fit,'sens',sens, ...
                 'vaf_validation',vaf_va,'aic_validation',aic_va, ...
                 'dwell_pts',dwell_pts);
save(fullfile(cfg.out_dir, 'results.mat'), '-struct', 'results');
fprintf('Done. Results in %s\n', cfg.out_dir);
