function frf = frf_welch(u, y, fs, opts)
% FRF_WELCH  H1 frequency response and magnitude-squared coherence via Welch.
%
%   frf = sysid.frf_welch(u, y, fs, opts)
%
%   Inputs:
%     u, y : input/output column vectors (same length, uniformly sampled)
%     fs   : sample rate (Hz)
%     opts : optional struct
%       .nfft     FFT length per segment            (default min(8192,N/4))
%       .overlap  fraction overlap, 0..1            (default 0.5)
%       .window   window function handle            (default @hann)
%       .fmin,.fmax  optional freq trim for output  (default [0, fs/2])
%
%   Output struct frf:
%     .f     frequency vector (Hz, column)
%     .H     complex H1 estimate = Pyu / Puu
%     .mag   |H|
%     .phase angle(H), unwrapped, radians
%     .coh2  magnitude-squared coherence
%     .Puu, .Pyy, .Pyu  raw spectra (one-sided)

    if nargin < 4, opts = struct(); end
    N = numel(u);
    if ~isfield(opts,'nfft'),    opts.nfft    = min(8192, max(256, 2^nextpow2(N/4))); end
    if ~isfield(opts,'overlap'), opts.overlap = 0.5; end
    if ~isfield(opts,'window'),  opts.window  = @hann; end
    if ~isfield(opts,'fmin'),    opts.fmin    = 0;     end
    if ~isfield(opts,'fmax'),    opts.fmax    = fs/2;  end

    % Cap segment length so we always get >=2 averaging segments
    max_seg = max(64, 2^floor(log2(N/2)));
    if opts.nfft > max_seg
        warning('sysid:frf_welch:nfft_capped', ...
            ['Requested nfft=%d > N/2=%d for record of N=%d samples; ' ...
             'capping nfft=%d so Welch can form >=2 segments.'], ...
            opts.nfft, floor(N/2), N, max_seg);
        opts.nfft = max_seg;
    end

    win   = opts.window(opts.nfft);
    nover = round(opts.overlap * opts.nfft);

    [Puu, f] = pwelch(u, win, nover, opts.nfft, fs, 'onesided');
    [Pyy, ~] = pwelch(y, win, nover, opts.nfft, fs, 'onesided');
    [Pyu, ~] = cpsd(y, u, win, nover, opts.nfft, fs, 'onesided');

    H = Pyu ./ Puu;
    coh2 = (abs(Pyu).^2) ./ max(Puu .* Pyy, eps);

    mask = f >= opts.fmin & f <= opts.fmax;
    frf.f     = f(mask);
    frf.H     = H(mask);
    frf.mag   = abs(frf.H);
    frf.phase = unwrap(angle(frf.H));
    frf.coh2  = coh2(mask);
    frf.Puu = Puu(mask); frf.Pyy = Pyy(mask); frf.Pyu = Pyu(mask);
end
