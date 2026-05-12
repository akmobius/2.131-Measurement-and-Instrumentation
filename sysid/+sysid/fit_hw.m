function fit = fit_hw(u, y, fs, opts)
% FIT_HW  Identify a Hammerstein–Wiener model: static f(u) → LTI → static g(z).
%
%   fit = sysid.fit_hw(u, y, fs)
%   fit = sysid.fit_hw(u, y, fs, opts)
%
% Wraps `nlhw` from the System Identification Toolbox. Defaults to a 3rd-
% order polynomial for both static blocks.
%
% opts:
%   .nb                 number of B numerator coefficients (default 4)
%   .nf                 number of F denominator coefficients (default 4)
%   .nk                 input delay in samples (default 0)
%   .input_nl           'poly3' (default), 'poly5', 'sigmoid', 'pwlinear', 'saturation'
%   .output_nl          same options as input_nl (default 'poly3')
%
% Returns:
%   .sys                idnlhw object
%   .opts               options used
%   .fit_percent_train  reported fit percentage on training data
%
% Required: System Identification Toolbox.

    if nargin < 4, opts = struct(); end
    if ~isfield(opts,'nb'),        opts.nb        = 2;          end
    if ~isfield(opts,'nf'),        opts.nf        = 2;          end
    if ~isfield(opts,'nk'),        opts.nk        = 0;          end
    if ~isfield(opts,'input_nl'),  opts.input_nl  = 'pwlinear'; end
    if ~isfield(opts,'output_nl'), opts.output_nl = 'unitgain'; end  % Hammerstein

    Ts = 1/fs;
    train_data = iddata(y(:), u(:), Ts);

    inputNL  = make_nonlinearity(opts.input_nl);
    outputNL = make_nonlinearity(opts.output_nl);

    % Robust fit options. (nlhw doesn't support a 'Focus' setting like
    % tfest does — simulation-error fitting is the default behavior.)
    nlhw_opts = nlhwOptions('SearchMethod','lm','Display','off');

    sys = nlhw(train_data, [opts.nb opts.nf opts.nk], ...
               inputNL, outputNL, nlhw_opts);

    fit.sys                = sys;
    fit.opts               = opts;
    fit.fit_percent_train  = sys.Report.Fit.FitPercent;

    % Sanity-check pole stability of the linear block
    try
        poles = pole(sys);
        max_pole_mag = max(abs(poles));
        if max_pole_mag > 0.999
            warning('sysid:fit_hw:unstable', ...
                ['Linear block has pole at |p|=%.3f (≥1) — model is ' ...
                 'unstable and will diverge in simulation. Try lower ' ...
                 'order (nb=nf=1 or 2) or a bounded input NL.'], max_pole_mag);
        end
        fit.max_pole_mag = max_pole_mag;
    catch
        fit.max_pole_mag = NaN;
    end
end

function nl = make_nonlinearity(name)
    switch lower(name)
        case 'poly3',      nl = idPolynomial1D('Degree', 3);
        case 'poly5',      nl = idPolynomial1D('Degree', 5);
        case 'sigmoid',    nl = idSigmoidNetwork(10);
        case 'pwlinear',   nl = idPiecewiseLinear('NumberOfUnits', 10);
        case 'saturation', nl = idSaturation;
        case 'deadzone',   nl = idDeadZone;
        case 'unitgain',   nl = idUnitGain;
        otherwise
            error('sysid:fit_hw:badNL', ...
                  'Unknown nonlinearity name "%s".', name);
    end
end
