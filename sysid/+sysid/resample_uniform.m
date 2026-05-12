function out = resample_uniform(data, fs)
% RESAMPLE_UNIFORM  Interpolate every channel onto a common uniform grid.
%
%   out = sysid.resample_uniform(data, fs)
%
%   Inputs:
%     data : struct from sysid.load_csv (each role has .t and .y)
%     fs   : target sample rate (Hz). If [], uses min native rate.
%
%   Output:
%     out.t           : uniform time vector (seconds, starts at 0)
%     out.fs          : sample rate used
%     out.<role>      : resampled signal vector (column)
%     out.roles       : cellstr list of role names

    roles = setdiff(fieldnames(data), {'fs_native'});
    if nargin < 2 || isempty(fs)
        fs = min(data.fs_native);
    end

    % Common time window = intersection of all channels
    t_start = -inf; t_end = inf;
    for k = 1:numel(roles)
        t = data.(roles{k}).t;
        t_start = max(t_start, t(1));
        t_end   = min(t_end,   t(end));
    end
    if t_end <= t_start
        error('sysid:resample_uniform:noOverlap', ...
              'Channel time windows do not overlap.');
    end

    dt = 1/fs;
    t_uni = (0:dt:(t_end - t_start))';

    out = struct();
    out.t  = t_uni;
    out.fs = fs;
    out.roles = roles;
    for k = 1:numel(roles)
        t = data.(roles{k}).t - t_start;
        y = data.(roles{k}).y;
        out.(roles{k}) = interp1(t, y, t_uni, 'linear', 'extrap');
    end
end
