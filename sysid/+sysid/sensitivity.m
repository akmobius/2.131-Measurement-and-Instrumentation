function sens = sensitivity(fit, frf, opts)
% SENSITIVITY  Parametric sensitivity: sweep each fitted parameter ±X% and
% record SSE between predicted and measured FRF.
%
%   sens = sysid.sensitivity(fit, frf, opts)
%
%   opts:
%     .pct      sweep range as fraction (default 0.20)
%     .npts     number of points per parameter (default 21)
%     .weight   'coh2' | 'unity' (default 'coh2')
%
%   Returns struct array sens with fields per parameter:
%     .name, .values, .sse, .center

    if nargin < 3, opts = struct(); end
    if ~isfield(opts,'pct'),    opts.pct    = 0.20; end
    if ~isfield(opts,'npts'),   opts.npts   = 21;   end
    if ~isfield(opts,'weight'), opts.weight = 'coh2'; end

    f = frf.f; w = 2*pi*f;
    Hm = frf.H;
    if strcmpi(opts.weight,'coh2')
        W = sqrt(max(frf.coh2, 1e-3));
    else
        W = ones(size(f));
    end

    sens = struct('name',{},'values',{},'sse',{},'center',{});
    p0 = fit.params;
    for k = 1:numel(p0)
        center = p0(k);
        sweep  = linspace(center*(1-opts.pct), center*(1+opts.pct), opts.npts);
        sse = zeros(size(sweep));
        for j = 1:numel(sweep)
            p = p0; p(k) = sweep(j);
            [num, den] = local_params_to_tf(p, fit.order);
            Hp = polyval(num, 1i*w) ./ polyval(den, 1i*w);
            e  = (Hp - Hm) .* W;
            sse(j) = sum(abs(e).^2);
        end
        sens(end+1).name = fit.param_names{k}; %#ok<AGROW>
        sens(end).values = sweep;
        sens(end).sse    = sse;
        sens(end).center = center;
    end
end

function [num, den] = local_params_to_tf(p, order)
    if order == 1
        num = p(1)*p(2); den = [1, p(2)];
    elseif order == 2
        num = p(1)*p(2)^2; den = [1, 2*p(3)*p(2), p(2)^2];
    else
        den = [1, p(2:end)];
        num = p(1) * den(end);
    end
end
