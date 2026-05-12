function [t_start, t_end, info] = detect_activity(y, fs, opts)
% DETECT_ACTIVITY  Find when a signal stops being quiescent.
%
%   [t_start, t_end] = sysid.detect_activity(y, fs)
%   [t_start, t_end, info] = sysid.detect_activity(y, fs, opts)
%
% Strategy: compute a moving standard deviation in a sliding window. The
% lowest moving-std values represent the noise floor (pre/post-test
% silence). Threshold at K × baseline. First crossing = test start; last
% crossing = test end. A small margin pads each end so transients aren't
% clipped.
%
% opts (all optional):
%   .win_sec      sliding-window length, sec (default 0.5)
%   .thresh_mult  threshold = thresh_mult × baseline noise (default 4)
%   .margin_sec   padding added before/after detected bounds (default 0.2)
%   .baseline_q   quantile of moving-std used as baseline   (default 0.10)
%
% Returns:
%   t_start, t_end : detected activity bounds in seconds (0-based)
%   info           : struct with diagnostic fields
%
% If no activity is detected, returns the full record [0, (N-1)/fs] and
% emits a warning.

    if nargin < 3, opts = struct(); end
    if ~isfield(opts,'win_sec'),     opts.win_sec     = 0.5;  end
    if ~isfield(opts,'thresh_mult'), opts.thresh_mult = 4;    end
    if ~isfield(opts,'margin_sec'),  opts.margin_sec  = 0.2;  end
    if ~isfield(opts,'baseline_q'),  opts.baseline_q  = 0.10; end

    y = y(:) - median(y);
    N = numel(y);
    W = max(8, round(opts.win_sec * fs));

    % Moving std (centered window)
    ms = movstd(y, W);

    % Baseline = quantile of the lowest moving-std values (assumed quiet)
    baseline = quantile(ms, opts.baseline_q);
    threshold = opts.thresh_mult * baseline;

    active = ms > threshold;
    i_start = find(active, 1, 'first');
    i_end   = find(active, 1, 'last');

    if isempty(i_start) || isempty(i_end)
        warning('sysid:detect_activity:noActivity', ...
            'No activity detected (max moving std = %.3g, threshold = %.3g). Returning full record.', ...
            max(ms), threshold);
        i_start = 1; i_end = N;
    end

    % Pad with margin
    margin = round(opts.margin_sec * fs);
    i_start = max(1, i_start - margin);
    i_end   = min(N, i_end   + margin);

    t_start = (i_start - 1) / fs;
    t_end   = (i_end   - 1) / fs;

    info = struct( ...
        'baseline',  baseline, ...
        'threshold', threshold, ...
        'i_start',   i_start, ...
        'i_end',     i_end, ...
        'fraction_active', mean(active));
end
