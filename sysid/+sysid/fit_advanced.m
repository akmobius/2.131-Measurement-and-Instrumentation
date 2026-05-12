function fits = fit_advanced(frf, u_tr, y_tr, fs, opts)
% FIT_ADVANCED  Try several parametric model structures against the Bode plot.
%
%   fits = sysid.fit_advanced(frf, u_tr, y_tr, fs)
%   fits = sysid.fit_advanced(frf, u_tr, y_tr, fs, opts)
%
% Tries multiple linear parametric structures (each physically motivated)
% and returns all results in one struct. The fits ARE linear models — they
% serve as Best Linear Approximations (BLAs) at the test amplitude. Each
% has a different physical interpretation:
%
%   2p / 0z  →  Helmholtz-resonator mode (single resonance)
%   2p / 0z + delay  →  Helmholtz + tubing transport delay
%   PT2 (procest) →  two coupled first-order lags
%   PT2 + delay (procest) →  two first-order lags + transport delay
%   4p / 2z  →  two-mode response (empirical higher-order)
%
% Inputs:
%   frf   struct from sysid.frf_welch
%   u_tr  training-half input vector
%   y_tr  training-half output vector
%   fs    sample rate (Hz)
%   opts  struct (optional):
%     .amplitude_mm   stamp on each fit (for BLA labeling, no math effect)
%
% Returns struct `fits` keyed by short method names; each entry has:
%   .name        display string
%   .num, .den   continuous-time numerator/denominator
%   .delay       transport delay (s); 0 if none
%   .H_pred      predicted FRF on frf.f
%   .cost        coherence-weighted squared error against frf.H
%   .physical    one-line physical interpretation
%
% Requires the System Identification Toolbox for tfest / procest.

    if nargin < 5, opts = struct(); end
    if ~isfield(opts,'amplitude_mm'), opts.amplitude_mm = NaN; end

    fits = struct();

    % --- Set up data objects for the System ID Toolbox ---
    Ts = 1/fs;
    time_data = iddata(y_tr(:), u_tr(:), Ts);
    w_rad     = 2*pi*frf.f(:);
    freq_data = idfrd(frf.H(:), w_rad, 0);   % Ts=0 → continuous-time
    s_eval    = 1i * 2*pi*frf.f;

    % --- Method 1: tfest 2p/0z (Helmholtz mode) ---
    fits = try_fit(fits, 'helm', ...
        '2p/0z (Helmholtz)', ...
        'Single resonance: K·ωn² / (s² + 2ζωn·s + ωn²) — represents one dominant compliant-mass mode (e.g. balloon + water column)', ...
        @() tfest_via_idfrd(freq_data, 2, 0, 0), ...
        s_eval);

    % --- Method 2: tfest 2p/0z with transport delay ---
    fits = try_fit(fits, 'helm_delay', ...
        '2p/0z + delay', ...
        'Helmholtz + transport delay — adds finite propagation time through tubing (sound/fluid wave delay)', ...
        @() tfest_via_idfrd(freq_data, 2, 0, NaN), ...
        s_eval);

    % --- Method 3: procest PT2 (no delay) ---
    fits = try_fit(fits, 'pt2', ...
        'procest PT2', ...
        'Two cascaded first-order lags: K / ((1+T1·s)(1+T2·s)) — two coupled fluid-circuit RC stages', ...
        @() procest_struct(time_data, 'P2'), ...
        s_eval);

    % --- Method 4: procest PT2D (with delay) ---
    fits = try_fit(fits, 'pt2d', ...
        'procest PT2D', ...
        'Two first-order lags + delay — same as PT2 with explicit transport delay through tubing', ...
        @() procest_struct(time_data, 'P2D'), ...
        s_eval);

    % --- Method 5: tfest 4p/2z (empirical two-mode) ---
    fits = try_fit(fits, 'two_mode', ...
        '4p/2z (two-mode)', ...
        'Two coupled second-order modes — captures two resonances simultaneously (e.g. air-side + fluid-side)', ...
        @() tfest_via_idfrd(freq_data, 4, 2, 0), ...
        s_eval);

    % --- Method 6: tfest 4p/2z with delay ---
    fits = try_fit(fits, 'two_mode_delay', ...
        '4p/2z + delay', ...
        'Two-mode response + transport delay — most general; useful when both two modes and a finite delay are present', ...
        @() tfest_via_idfrd(freq_data, 4, 2, NaN), ...
        s_eval);

    % --- Method 7: high-order tfest 8p/4z (empirical, more flexible) ---
    fits = try_fit(fits, 'flex_8p4z', ...
        '8p/4z (high-order empirical)', ...
        'High-order empirical fit — more flexibility means closer visual match but starts to chase noise rather than physics. Use to see where overfitting begins.', ...
        @() tfest_via_idfrd(freq_data, 8, 4, 0), ...
        s_eval);

    % --- Method 8: very high order, 12p/6z (overfitting territory) ---
    fits = try_fit(fits, 'overfit_12p6z', ...
        '12p/6z (likely overfitting)', ...
        'Very-high-order fit — flexible enough to follow most wiggles, but parameters lose all physical meaning and predictive value drops on validation data. Cautionary illustration.', ...
        @() tfest_via_idfrd(freq_data, 12, 6, 0), ...
        s_eval);

    % --- Stamp amplitude on every result ---
    fnames = fieldnames(fits);
    for k = 1:numel(fnames)
        fits.(fnames{k}).amplitude_mm = opts.amplitude_mm;
    end

    % --- Compute coherence-weighted cost for each ---
    H_data = frf.H(:);
    w = sqrt(max(frf.coh2(:), 1e-3));
    for k = 1:numel(fnames)
        nm = fnames{k};
        if isfield(fits.(nm),'H_pred') && ~isempty(fits.(nm).H_pred)
            e = (fits.(nm).H_pred(:) - H_data) .* w;
            fits.(nm).cost = sum(abs(e).^2);
        else
            fits.(nm).cost = NaN;
        end
    end
end

% =============================================================================
% Helpers
% =============================================================================

function fits = try_fit(fits, key, name, physical, fit_fn, s_eval)
% Wraps each fit in a try/catch so one method's failure doesn't kill the rest.
    try
        result = fit_fn();
        if isempty(result), return; end
        result.name = name;
        result.physical = physical;
        % If the method didn't pre-fill H_pred, compute it from (num, den, delay)
        if ~isfield(result,'H_pred') || isempty(result.H_pred)
            H = polyval(result.num, s_eval) ./ polyval(result.den, s_eval);
            if isfield(result,'delay') && ~isempty(result.delay) && result.delay > 0
                H = H .* exp(-result.delay * s_eval);
            end
            result.H_pred = H;
        end
        if ~isfield(result,'delay'), result.delay = 0; end
        fits.(key) = result;
    catch ME
        fprintf('[fit_advanced] %s failed: %s\n', name, ME.message);
    end
end

function r = tfest_via_idfrd(idfrd_data, np, nz, ioDelay)
% Run tfest with the given pole/zero/delay specification.
%   ioDelay = 0  → no delay
%   ioDelay = NaN → estimate the delay
    if nargin < 4, ioDelay = 0; end
    sys = tfest(idfrd_data, np, nz, ioDelay);
    r.num = sys.Numerator;
    r.den = sys.Denominator;
    r.delay = sys.IODelay;
end

function r = procest_struct(time_data, model_type)
% Run procest with the given process-model type string (e.g. 'P2', 'P2D').
% Returns continuous-time num/den + delay.
    sys = procest(time_data, model_type);
    % Convert the process model to a transfer function for evaluation
    [num, den] = tfdata(tf(sys), 'v');
    r.num = num;
    r.den = den;
    if isprop(sys, 'Td')
        r.delay = sys.Td;
    else
        r.delay = 0;
    end
end
