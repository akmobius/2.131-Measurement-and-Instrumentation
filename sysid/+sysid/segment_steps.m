function segs = segment_steps(t, u, opts)
% SEGMENT_STEPS  Find step / large-transition events in the input signal.
%
%   segs = sysid.segment_steps(t, u, opts)
%
%   Detects rising and falling edges by thresholding the smoothed derivative,
%   and returns response windows from each edge for `post_sec` seconds.
%
%   opts:
%     .smooth_sec  smoothing window for derivative (default 0.05)
%     .thresh      derivative threshold as fraction of peak (default 0.25)
%     .pre_sec     samples to keep before edge   (default 0.1)
%     .post_sec    samples to keep after edge    (default 2.0)
%     .min_gap_sec minimum spacing between edges (default 0.5)
%
%   Returns struct array with .i0, .i1, .i_edge, .direction (+1/-1).

    if nargin < 3, opts = struct(); end
    if ~isfield(opts,'smooth_sec'),  opts.smooth_sec  = 0.05; end
    if ~isfield(opts,'thresh'),      opts.thresh      = 0.25; end
    if ~isfield(opts,'pre_sec'),     opts.pre_sec     = 0.1;  end
    if ~isfield(opts,'post_sec'),    opts.post_sec    = 2.0;  end
    if ~isfield(opts,'min_gap_sec'), opts.min_gap_sec = 0.5;  end

    fs = 1/median(diff(t));
    Nsm = max(3, round(opts.smooth_sec*fs));
    du  = [0; diff(movmean(u, Nsm))];
    thr = opts.thresh * max(abs(du));

    edges = find(abs(du) > thr);
    % collapse runs of close edges
    if ~isempty(edges)
        keep = [true; diff(edges) > round(opts.min_gap_sec*fs)];
        edges = edges(keep);
    end

    pre  = round(opts.pre_sec*fs);
    post = round(opts.post_sec*fs);
    N    = numel(u);
    segs = struct('i0',{},'i1',{},'i_edge',{},'direction',{});
    for k = 1:numel(edges)
        e  = edges(k);
        i0 = max(1, e - pre);
        i1 = min(N, e + post);
        s.i0 = i0; s.i1 = i1; s.i_edge = e;
        s.direction = sign(du(e));
        segs(end+1) = s; %#ok<AGROW>
    end
end
