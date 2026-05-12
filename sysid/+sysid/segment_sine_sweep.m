function segs = segment_sine_sweep(t, u, opts)
% SEGMENT_SINE_SWEEP  Find constant-frequency dwell windows in a stepped sine sweep.
%
%   segs = sysid.segment_sine_sweep(t, u, opts)
%
%   Strategy: slide an FFT window across the input; in each window find the
%   dominant frequency. Group consecutive windows that share the same dominant
%   frequency (within tolerance) into one dwell segment. Drop the leading
%   `transient_cycles` cycles from each segment.
%
%   opts fields (all optional):
%     .win_sec          window length for FFT, sec       (default 1.0)
%     .hop_sec          step between windows, sec        (default 0.25)
%     .freq_tol         relative freq tolerance to group (default 0.05)
%     .min_dwell_sec    drop dwells shorter than this    (default 1.0)
%     .transient_cycles cycles to drop at start of dwell (default 3)
%
%   Returns struct array `segs` with fields:
%     .f0   dominant frequency (Hz)
%     .i0   start sample index (after transient trim)
%     .i1   end sample index
%     .n    number of samples

    if nargin < 3, opts = struct(); end
    if ~isfield(opts,'win_sec'),          opts.win_sec = 1.0;        end
    if ~isfield(opts,'hop_sec'),          opts.hop_sec = 0.25;       end
    if ~isfield(opts,'freq_tol'),         opts.freq_tol = 0.05;      end
    if ~isfield(opts,'min_dwell_sec'),    opts.min_dwell_sec = 1.0;  end
    if ~isfield(opts,'transient_cycles'), opts.transient_cycles = 3; end

    fs  = 1/median(diff(t));
    Nw  = max(8, round(opts.win_sec*fs));
    Hop = max(1, round(opts.hop_sec*fs));
    N   = numel(u);

    starts = 1:Hop:(N - Nw + 1);
    domF   = zeros(numel(starts),1);
    for k = 1:numel(starts)
        i0 = starts(k);
        seg = u(i0:i0+Nw-1) - mean(u(i0:i0+Nw-1));
        Y = abs(fft(seg .* hann(Nw)));
        Y = Y(1:floor(Nw/2));
        f = (0:numel(Y)-1)' * fs / Nw;
        [~, idx] = max(Y(2:end));    % skip DC
        domF(k) = f(idx+1);
    end

    % Group consecutive windows by frequency proximity
    segs = struct('f0',{},'i0',{},'i1',{},'n',{});
    if isempty(domF), return; end
    grp_start = 1;
    for k = 2:numel(domF)
        if abs(domF(k) - domF(grp_start)) / max(domF(grp_start),eps) > opts.freq_tol
            segs(end+1) = build_seg(domF, starts, grp_start, k-1, Nw, fs, opts); %#ok<AGROW>
            grp_start = k;
        end
    end
    segs(end+1) = build_seg(domF, starts, grp_start, numel(domF), Nw, fs, opts);

    % Drop too-short dwells
    durs = arrayfun(@(s) s.n/fs, segs);
    segs = segs(durs >= opts.min_dwell_sec);
end

function s = build_seg(domF, starts, k0, k1, Nw, fs, opts)
    f0 = median(domF(k0:k1));
    i_start = starts(k0);
    i_end   = starts(k1) + Nw - 1;
    trim    = round(opts.transient_cycles * fs / max(f0,eps));
    s.f0 = f0;
    s.i0 = min(i_end, i_start + trim);
    s.i1 = i_end;
    s.n  = s.i1 - s.i0 + 1;
end
