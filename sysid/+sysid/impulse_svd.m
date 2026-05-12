function ir = impulse_svd(u, y, fs, opts)
% IMPULSE_SVD  Impulse response via SVD-regularized solution to the
% Wiener-Hopf equation R_uu * h = R_yu (Toeplitz form).
%
%   ir = sysid.impulse_svd(u, y, fs, opts)
%
%   Builds the autocorrelation Toeplitz matrix of u and the cross-correlation
%   vector of (y,u), takes the (truncated) SVD pseudo-inverse, and returns the
%   impulse response h such that y ≈ conv(h, u) * dt.
%
%   opts:
%     .L           IR length in samples         (default round(0.5*fs))
%     .sv_keep     fraction of singular values to keep (default 0.95)
%     .reg         additive ridge (relative to max sv) (default 1e-3)
%
%   Returns:
%     ir.t       time vector for h
%     ir.h       impulse response (per second; conv with u then * dt = y)
%     ir.gain_dc sum(h)*dt = static gain
%     ir.method  'svd-toeplitz'

    if nargin < 4, opts = struct(); end
    if ~isfield(opts,'L'),       opts.L       = round(0.5*fs); end
    if ~isfield(opts,'sv_keep'), opts.sv_keep = 0.95;          end
    if ~isfield(opts,'reg'),     opts.reg     = 1e-3;          end

    L  = opts.L;
    dt = 1/fs;
    u  = u(:); y = y(:);

    % Biased autocorr (matches sum convention used to build Toeplitz)
    Ruu = xcorr(u, L-1, 'biased');     % length 2L-1
    Ryu = xcorr(y, u, L-1, 'biased');  % length 2L-1
    rcol = Ruu(L:end);                 % lags 0..L-1
    R    = toeplitz(rcol);
    p    = Ryu(L:end);                 % lags 0..L-1, y vs u

    [U,S,V] = svd(R);
    s = diag(S);
    cum = cumsum(s) / sum(s);
    keep = find(cum >= opts.sv_keep, 1, 'first');
    if isempty(keep), keep = numel(s); end
    s_inv = zeros(size(s));
    reg = opts.reg * s(1);
    s_inv(1:keep) = s(1:keep) ./ (s(1:keep).^2 + reg^2);
    Rpinv = V * diag(s_inv) * U';

    h = Rpinv * p;
    h = h / dt;   % normalize so that conv(h,u)*dt approximates y

    ir.t = (0:L-1)' * dt;
    ir.h = h;
    ir.gain_dc = sum(h) * dt;
    ir.method = 'svd-toeplitz';
end
