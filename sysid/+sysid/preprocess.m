function out = preprocess(in, opts)
% PREPROCESS  Detrend, low-pass (zero-phase), and optionally notch each channel.
%
%   out = sysid.preprocess(in, opts)
%
%   in   : struct from sysid.resample_uniform
%   opts : struct with optional fields
%     .channels    cellstr of role names to process (default: in.roles)
%     .detrend     'mean' | 'linear' | 'none'           (default 'mean')
%     .lp_cutoff   low-pass cutoff in Hz, [] to skip    (default [])
%     .lp_order    Butterworth order                    (default 4)
%     .notch_f0    notch frequency Hz, [] to skip       (default [])
%     .notch_Q     notch quality factor                 (default 30)
%     .trim_sec      seconds to drop from start of record (default 0)
%     .trim_end_sec  seconds to drop from end   of record (default 0)
%
%   Returns a struct with the same shape as `in` but with channels filtered
%   in-place. Always preserves .t, .fs, .roles. Uses filtfilt for zero phase.

    if nargin < 2, opts = struct(); end
    if ~isfield(opts,'channels'),     opts.channels     = in.roles; end
    if ~isfield(opts,'detrend'),      opts.detrend      = 'mean';   end
    if ~isfield(opts,'lp_cutoff'),    opts.lp_cutoff    = [];       end
    if ~isfield(opts,'lp_order'),     opts.lp_order     = 4;        end
    if ~isfield(opts,'notch_f0'),     opts.notch_f0     = [];       end
    if ~isfield(opts,'notch_Q'),      opts.notch_Q      = 30;       end
    if ~isfield(opts,'trim_sec'),     opts.trim_sec     = 0;        end
    if ~isfield(opts,'trim_end_sec'), opts.trim_end_sec = 0;        end

    out = in;
    fs  = in.fs;

    % Trim from start and end
    t_lo = opts.trim_sec;
    t_hi = out.t(end) - opts.trim_end_sec;
    if t_hi <= t_lo
        error('sysid:preprocess:trimAll', ...
              'trim_sec (%.2f) + trim_end_sec (%.2f) leave no data (record %.2f s).', ...
              opts.trim_sec, opts.trim_end_sec, out.t(end));
    end
    if opts.trim_sec > 0 || opts.trim_end_sec > 0
        keep = out.t >= t_lo & out.t <= t_hi;
        out.t = out.t(keep) - out.t(find(keep,1));
        for k = 1:numel(out.roles)
            r = out.roles{k};
            out.(r) = out.(r)(keep);
        end
    end

    % Build filters once
    lp_b = []; lp_a = [];
    if ~isempty(opts.lp_cutoff)
        Wn = opts.lp_cutoff / (fs/2);
        if Wn >= 1
            warning('sysid:preprocess:lp_cutoff_above_nyquist', ...
                'LP cutoff %.2f Hz >= Nyquist (%.2f Hz); skipping LPF.', ...
                opts.lp_cutoff, fs/2);
        else
            [lp_b, lp_a] = butter(opts.lp_order, Wn, 'low');
        end
    end
    n_b = []; n_a = [];
    if ~isempty(opts.notch_f0)
        W0 = opts.notch_f0 / (fs/2);
        if W0 < 1
            [n_b, n_a] = iirnotch(W0, W0/opts.notch_Q);
        end
    end

    for k = 1:numel(opts.channels)
        r = opts.channels{k};
        y = out.(r);
        switch lower(opts.detrend)
            case 'mean',   y = y - mean(y);
            case 'linear', y = detrend(y, 'linear');
            case 'none'    % nothing
            otherwise, error('Unknown detrend option: %s', opts.detrend);
        end
        if ~isempty(lp_b), y = filtfilt(lp_b, lp_a, y); end
        if ~isempty(n_b),  y = filtfilt(n_b,  n_a,  y); end
        out.(r) = y;
    end
end
