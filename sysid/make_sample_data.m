function out_path = make_sample_data(out_dir)
% MAKE_SAMPLE_DATA  Synthesize a realistic-looking heart-pump CSV for testing.
%
%   out_path = make_sample_data()                % writes to sysid/sample_data/
%   out_path = make_sample_data('some/folder')   % writes there instead
%
% Generates a wide CSV with one time column and five channel columns matching
% the rig's roles. The "system" is two cascaded 2nd-order plants:
%
%   piston_pos -> outlet_water_q :  K=0.85, fn=2.4 Hz, zeta=0.30
%   piston_pos -> outlet_water_p :  K=12.0, fn=1.8 Hz, zeta=0.45
%   inlet_air_p / inlet_air_q    :  light low-pass of piston_pos
%
% Excitation is a stepped-sine sweep at 0.2, 0.5, 1, 2, 4, 8 Hz (8 s each)
% so the sample exercises both the Welch path and the per-dwell DFT path.

    if nargin < 1 || isempty(out_dir)
        out_dir = fullfile(fileparts(mfilename('fullpath')), 'sample_data');
    end
    if ~exist(out_dir,'dir'), mkdir(out_dir); end

    fs = 200;
    freqs   = [0.2 0.5 1 2 4 8];
    dwell_s = 8;
    amp_mm  = 8;

    t = []; u = [];
    for f0 = freqs
        tk = (0:1/fs:dwell_s-1/fs)';
        uk = amp_mm * sin(2*pi*f0*tk);
        if isempty(t), t = tk; else, t = [t; t(end) + 1/fs + tk]; end %#ok<AGROW>
        u = [u; uk]; %#ok<AGROW>
    end
    N = numel(t);

    % --- "True" plants (continuous-time num/den) ---
    mk2 = @(K,fn,z) deal(K*(2*pi*fn)^2, [1, 2*z*(2*pi*fn), (2*pi*fn)^2]);
    [n_q,  d_q ] = mk2(0.85, 2.4, 0.30);
    [n_p,  d_p ] = mk2(12.0, 1.8, 0.45);
    [n_ap, d_ap] = mk2(1.0,  15,  0.7);   % near-unity LPF
    [n_aq, d_aq] = mk2(1.0,  8,   0.7);

    % --- Simulate (no Control System Toolbox needed) ---
    out_q = sysid.sim_ct(n_q,  d_q,  u, fs);
    out_p = sysid.sim_ct(n_p,  d_p,  u, fs);
    air_p = -1.5 * sysid.sim_ct(n_ap, d_ap, u, fs);    % vacuum -> negative
    air_q = -0.8 * sysid.sim_ct(n_aq, d_aq, gradient(u, 1/fs), fs);

    % --- Add measurement noise (different SNR per channel) ---
    rng(7);  % reproducible
    out_q = out_q + 0.02*std(out_q)*randn(N,1);
    out_p = out_p + 0.02*std(out_p)*randn(N,1);
    air_p = air_p + 0.05*std(air_p)*randn(N,1);
    air_q = air_q + 0.05*std(air_q)*randn(N,1);

    % --- Write wide CSV ---
    T = table(t, u, air_p, air_q, out_p, out_q, ...
        'VariableNames',{'time_s','piston_pos_mm','inlet_air_pressure', ...
                         'inlet_air_flow','outlet_water_pressure','outlet_water_flow'});
    out_path = fullfile(out_dir, 'sweep_sample.csv');
    writetable(T, out_path);
    fprintf('Wrote %s  (%d rows, %.1f s, fs=%.0f Hz)\n', out_path, N, t(end), fs);
end
