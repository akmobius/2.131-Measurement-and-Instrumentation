function pts = frf_sine_dwell(u, y, fs, segs)
% FRF_SINE_DWELL  Per-dwell single-tone FRF point from a sine-sweep record.
%
%   pts = sysid.frf_sine_dwell(u, y, fs, segs)
%
%   For each segment from sysid.segment_sine_sweep, demodulate u and y at
%   the segment's fundamental frequency by a tight DFT bin (sine/cosine
%   inner products). Returns one (mag, phase, coh2) point per dwell.
%
%   Output struct array pts:
%     .f, .mag, .phase (rad), .coh2

    pts = struct('f',{},'mag',{},'phase',{},'coh2',{});
    for k = 1:numel(segs)
        i0 = segs(k).i0; i1 = segs(k).i1;
        if i1 - i0 < 8, continue; end
        f0 = segs(k).f0;
        n  = (i0:i1)';
        tt = (n - n(1)) / fs;
        c  = cos(2*pi*f0*tt);
        s  = sin(2*pi*f0*tt);

        uw = u(i0:i1) - mean(u(i0:i1));
        yw = y(i0:i1) - mean(y(i0:i1));

        % complex amplitude  X = (1/N) sum x*(c - j s) * 2  (one-sided)
        Uc = 2/numel(n) * (c'*uw - 1i*(s'*uw));
        Yc = 2/numel(n) * (c'*yw - 1i*(s'*yw));

        H = Yc / Uc;
        % Coherence at single tone: ratio of energy at f0 to total in window
        Eu_tone = abs(Uc)^2 / 2;
        Ey_tone = abs(Yc)^2 / 2;
        Eu_tot  = mean(uw.^2);
        Ey_tot  = mean(yw.^2);
        coh2 = (Eu_tone/max(Eu_tot,eps)) * (Ey_tone/max(Ey_tot,eps));

        p.f = f0; p.mag = abs(H); p.phase = angle(H); p.coh2 = min(1, coh2);
        pts(end+1) = p; %#ok<AGROW>
    end
end
