function fit = fit_param_tf(frf, opts)
% FIT_PARAM_TF  Fit a parametric continuous-time transfer function to an FRF.
%
%   fit = sysid.fit_param_tf(frf, opts)
%
%   Default model: 2nd-order standard form
%       H(s) = K * wn^2 / (s^2 + 2*zeta*wn*s + wn^2)
%   parameter vector p = [K, wn, zeta].
%
%   For arbitrary order n, fit numerator (1 coefficient) and denominator
%   coefficients [a_(n-1) ... a_0] with leading 1.
%
%   opts:
%     .order      model order (2 default). 1 or 2 supported in standard
%                 form. For higher orders, fits free polynomial coeffs.
%     .init       initial parameter vector (auto-init if [])
%     .weight     'coh2' (default) | 'unity' — frequency-domain residual weight
%     .fmin,fmax  optional fit-band trim
%
%   Returns:
%     fit.params      fitted parameter vector
%     fit.num, fit.den  continuous-time numerator/denominator polynomials
%                     (use sysid.sim_ct(fit.num, fit.den, u, fs) to simulate)
%     fit.H_pred      predicted complex FRF on frf.f
%     fit.resnorm     final sum of squared residuals
%     fit.exitflag    lsqnonlin exit flag
%     fit.order       order used
%     fit.param_names cellstr of parameter names

    if nargin < 2, opts = struct(); end
    if ~isfield(opts,'order'),  opts.order  = 2;       end
    if ~isfield(opts,'weight'), opts.weight = 'coh2';  end
    if ~isfield(opts,'fmin'),   opts.fmin   = frf.f(1); end
    if ~isfield(opts,'fmax'),   opts.fmax   = frf.f(end); end

    mask = frf.f >= opts.fmin & frf.f <= opts.fmax & frf.f > 0;
    f    = frf.f(mask);
    Hm   = frf.H(mask);
    coh2 = frf.coh2(mask);
    w    = 2*pi*f;

    switch lower(opts.weight)
        case 'coh2',  W = sqrt(max(coh2, 1e-3));
        case 'unity', W = ones(size(f));
        otherwise,    error('Unknown weight: %s', opts.weight);
    end

    % --- initial guess ---
    if ~isfield(opts,'init') || isempty(opts.init)
        p0 = init_guess(f, Hm, opts.order);
    else
        p0 = opts.init;
    end

    % --- residual function ---
    resfun = @(p) pack_resid(p, w, Hm, W, opts.order);

    optset = optimoptions('lsqnonlin', ...
        'Algorithm','levenberg-marquardt', ...
        'Display','off', ...
        'MaxFunctionEvaluations', 4000, ...
        'MaxIterations', 800);
    [p_fit, resnorm, ~, exitflag] = lsqnonlin(resfun, p0, [], [], optset);

    [num, den] = params_to_tf(p_fit, opts.order);
    fit.params      = p_fit;
    fit.num         = num;
    fit.den         = den;
    fit.H_pred      = freqs_eval(num, den, 2*pi*frf.f);
    fit.resnorm     = resnorm;
    fit.exitflag    = exitflag;
    fit.order       = opts.order;
    fit.param_names = param_names(opts.order);
end

% ---------- helpers ----------

function p0 = init_guess(f, H, order)
    [magpk, ipk] = max(abs(H));
    fpk = f(ipk);
    K   = abs(H(1));            % crude DC gain
    wn  = 2*pi*max(fpk, f(2));
    if order == 1
        p0 = [K, wn];
    elseif order == 2
        % zeta from peak magnitude:  Mr = 1/(2*zeta*sqrt(1-zeta^2))
        Mr  = magpk / max(K, eps);
        zeta = 0.3;
        if Mr > 1.05
            zeta = max(0.05, sqrt(0.5 - 0.5*sqrt(max(0, 1 - 1/Mr^2))));
        end
        p0 = [K, wn, zeta];
    else
        % Free polynomial: place all `order` poles at -wn (repeated real
        % root). den = (s + wn)^order in standard descending-power form
        %       = sum_{k=0..order} C(order,k) * wn^k * s^(order-k)
        % Drop the leading 1, store the rest as the initial guess.
        den_coeffs = zeros(1, order+1);
        for kk = 0:order
            den_coeffs(kk+1) = nchoosek(order, kk) * wn^kk;
        end
        p0 = [K, den_coeffs(2:end)];
    end
end

function r = pack_resid(p, w, Hm, W, order)
    [num, den] = params_to_tf(p, order);
    Hp = freqs_eval(num, den, w);
    e  = (Hp - Hm) .* W;
    r  = [real(e); imag(e)];
end

function H = freqs_eval(num, den, w)
    s = 1i * w;
    H = polyval(num, s) ./ polyval(den, s);
end

function [num, den] = params_to_tf(p, order)
    if order == 1
        K = p(1); wn = p(2);
        num = K * wn;
        den = [1, wn];
    elseif order == 2
        K = p(1); wn = p(2); zeta = p(3);
        num = K * wn^2;
        den = [1, 2*zeta*wn, wn^2];
    else
        % p = [K, a_(n-1), ..., a_0]
        K = p(1);
        den = [1, p(2:end)];
        num = K * den(end);
    end
end

function names = param_names(order)
    if     order == 1, names = {'K','wn'};
    elseif order == 2, names = {'K','wn','zeta'};
    else
        names = [{'K'}, arrayfun(@(k) sprintf('a%d',order-k), 1:order, 'uni', 0)];
    end
end
