function manual_fit_explorer(frf, fit_init)
% MANUAL_FIT_EXPLORER  Interactive Bode plot for tweaking model parameters by hand.
%
%   sysid.manual_fit_explorer(frf)
%   sysid.manual_fit_explorer(frf, fit_init)
%
% Opens a window showing the FRF data alongside a parametric model whose
% parameters you adjust via sliders and numeric fields. The model curve
% updates live. The equation is rendered at the top of the controls panel
% in Unicode form using the current numerical values.
%
% Useful for:
%   - Building intuition about how K, ωn, ζ shape the response
%   - Finding a good starting point manually when the LM auto-init fails
%   - Quickly testing what a particular pole structure would look like
%
% Inputs:
%   frf       struct from sysid.frf_welch (.f, .mag, .phase, .H)
%   fit_init  (optional) struct from sysid.fit_param_tf — used to seed the
%             initial parameter values. If omitted, defaults are computed
%             from the FRF.

    if nargin < 2, fit_init = []; end

    % --- Determine initial state ---
    if ~isempty(fit_init) && isfield(fit_init,'order')
        order  = fit_init.order;
        params = fit_init.params(:)';
        names  = fit_init.param_names;
    else
        order = 2;
        [params, names] = default_params(frf, order);
    end

    % --- Build the window ---
    fig = uifigure('Name','Manual Fit Explorer','Position',[120 60 1180 760]);

    layout = uigridlayout(fig, [3 1]);
    layout.RowHeight = {'1.4x','1.4x','1.5x'};   % mag, phase, controls

    axMag = uiaxes(layout); axMag.Layout.Row = 1;
    axPh  = uiaxes(layout); axPh.Layout.Row  = 2;
    ctrlPanel = uipanel(layout, 'Title','Model parameters', ...
                                'FontWeight','bold','BorderType','line');
    ctrlPanel.Layout.Row = 3;

    % Controls handles (rebuilt on order change)
    orderDD = [];
    eqLabel = [];
    sliderH = {};
    fieldH  = {};

    buildControls();
    redraw();

    % ============================ callbacks ============================
    function onParamChange(idx, newval)
        params(idx) = newval;
        if ~isempty(sliderH{idx})
            % Clamp to slider range to avoid an out-of-range error
            lo = sliderH{idx}.Limits(1);
            hi = sliderH{idx}.Limits(2);
            sliderH{idx}.Value = max(lo, min(hi, newval));
        end
        if ~isempty(fieldH{idx})
            fieldH{idx}.Value = newval;
        end
        redraw();
    end

    function onOrderChange(src, ~)
        newOrder = str2double(src.Value);
        if newOrder ~= order
            order = newOrder;
            [params, names] = default_params(frf, order);
            delete(allchild(ctrlPanel));
            buildControls();
            redraw();
        end
    end

    function onReset(~,~)
        if ~isempty(fit_init) && fit_init.order == order
            params = fit_init.params(:)';
        else
            [params, names] = default_params(frf, order);
        end
        for k = 1:numel(params)
            sliderH{k}.Value = max(sliderH{k}.Limits(1), ...
                                   min(sliderH{k}.Limits(2), params(k)));
            fieldH{k}.Value = params(k);
        end
        redraw();
    end

    function onClose(~,~)
        delete(fig);
    end

    function redraw()
        [num, den] = params_to_tf(params, order);
        s = 1i * 2*pi*frf.f;
        H_model = polyval(num, s) ./ polyval(den, s);

        % --- magnitude ---
        cla(axMag);
        hold(axMag,'on');
        plot(axMag, frf.f, frf.mag, '.-', 'Color',[0.20 0.40 0.70], ...
             'MarkerSize',6, 'LineWidth',0.5, 'DisplayName','Welch H_1');
        plot(axMag, frf.f, abs(H_model), '--', 'Color',[0.85 0.10 0.10], ...
             'LineWidth',2, 'DisplayName','Manual model');
        set(axMag,'XScale','log','YScale','log');
        ylabel(axMag,'|H|'); title(axMag,'Magnitude'); grid(axMag,'on');
        legend(axMag,'Location','best');

        % --- phase ---
        cla(axPh);
        hold(axPh,'on');
        plot(axPh, frf.f, rad2deg(frf.phase), '.-', 'Color',[0.20 0.40 0.70], ...
             'MarkerSize',6, 'LineWidth',0.5, 'DisplayName','Welch H_1');
        plot(axPh, frf.f, rad2deg(unwrap(angle(H_model))), '--', ...
             'Color',[0.85 0.10 0.10], 'LineWidth',2, 'DisplayName','Manual model');
        set(axPh,'XScale','log');
        ylabel(axPh,'phase (deg)'); xlabel(axPh,'frequency (Hz)');
        title(axPh,'Phase'); grid(axPh,'on');
        legend(axPh,'Location','best');

        % --- equation ---
        eqLabel.Text = format_equation(order, params);
    end

    function buildControls()
        nParam = numel(params);
        % Rows: order(1) + equation(1) + spacer(1) + nParam + actions(1)
        nRows  = 3 + nParam + 1;
        rowH   = [30, 50, 8, repmat(36, 1, nParam), 40];
        g = uigridlayout(ctrlPanel, [nRows 4]);
        g.RowHeight   = num2cell(rowH);
        g.ColumnWidth = {110, '1x', 110, 110};

        % Row 1: Order dropdown
        uilabel(g,'Text','Model order:','HorizontalAlignment','right', ...
                'FontWeight','bold');
        orderDD = uidropdown(g,'Items',{'1','2','3','4'}, ...
                                'Value',num2str(order), ...
                                'ValueChangedFcn',@onOrderChange);
        orderDD.Layout.Column = 2;
        uilabel(g,'Text','(rebuilds parameter sliders below)', ...
                'FontAngle','italic','FontSize',10,'FontColor',[0.4 0.4 0.4]);
        uilabel(g,'Text','');

        % Row 2: Equation
        uilabel(g,'Text','Equation:','HorizontalAlignment','right', ...
                'FontWeight','bold');
        eqLabel = uilabel(g,'Text','','FontName','Cambria Math', ...
                            'FontSize',14,'WordWrap','on');
        eqLabel.Layout.Column = [2 4];

        % Row 3: spacer
        uilabel(g,'Text','');

        % Parameter sliders + fields
        sliderH = cell(1, nParam);
        fieldH  = cell(1, nParam);
        for k = 1:nParam
            v = params(k);
            [lo, hi] = slider_range(names{k}, v);

            uilabel(g,'Text',[names{k} ':'],'HorizontalAlignment','right', ...
                    'FontWeight','bold');

            sl = uislider(g,'Limits',[lo hi],'Value',max(lo,min(hi,v)));
            % Live updates during drag, also at release
            sl.ValueChangingFcn = @(src,evt) onParamChange(k, evt.Value);
            sl.ValueChangedFcn  = @(src,~)  onParamChange(k, src.Value);
            sliderH{k} = sl;

            % Current value label
            uilabel(g,'Text',sprintf('%.4g', v),'HorizontalAlignment','center', ...
                    'FontName','Consolas','FontSize',12); %#ok<NASGU>

            ed = uieditfield(g,'numeric','Value',v);
            ed.ValueChangedFcn = @(src,~) onParamChange(k, src.Value);
            fieldH{k} = ed;
        end

        % Bottom row: actions
        uilabel(g,'Text','');   % spacer in column 1
        uilabel(g,'Text','');   % spacer in column 2
        resetBtn = uibutton(g,'Text','Reset', ...
                              'ButtonPushedFcn',@onReset);
        resetBtn.Layout.Column = 3;
        closeBtn = uibutton(g,'Text','Close', ...
                              'BackgroundColor',[0.85 0.95 0.85], ...
                              'ButtonPushedFcn',@onClose);
        closeBtn.Layout.Column = 4;
    end
end

% =============================================================================
%                                 HELPERS
% =============================================================================
function [params, names] = default_params(frf, order)
    [~, ipk] = max(frf.mag);
    fpk = frf.f(ipk);
    K   = abs(frf.H(1));
    wn  = 2*pi*max(fpk, frf.f(2));
    switch order
        case 1
            params = [K, wn];
            names = {'K','wn'};
        case 2
            params = [K, wn, 0.3];
            names = {'K','wn','zeta'};
        otherwise
            % (s + wn)^order — binomial coefficients
            binom = zeros(1, order+1);
            for kk = 0:order
                binom(kk+1) = nchoosek(order, kk) * wn^kk;
            end
            params = [K, binom(2:end)];
            names  = [{'K'}, arrayfun(@(k) sprintf('a%d',order-k), 1:order, 'uni', 0)];
    end
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
        K = p(1);
        den = [1, p(2:end)];
        num = K * den(end);
    end
end

function [lo, hi] = slider_range(name, v)
% Parameter-specific slider ranges. Designed to bracket the typical region
% of interest while still letting the user explore beyond the auto-init.
    av = abs(v); if av < eps, av = 1; end
    switch lower(name)
        case 'k'
            lo = 0;
            hi = av * 5;
        case 'wn'
            lo = av / 10;
            hi = av * 10;
        case 'zeta'
            lo = 0.01;
            hi = 2.0;
        otherwise
            % polynomial coefficient — broad symmetric range
            lo = -av * 5;
            hi =  av * 5;
            if lo == 0 && hi == 0
                lo = -10; hi = 10;
            end
    end
end

function txt = format_equation(order, params)
% Build a human-readable equation string using Unicode characters.
    SS_2  = char(178);   % ²
    SS_3  = char(179);   % ³
    SS_4  = char(8308);  % ⁴
    SUB_n = char(8345);  % ₙ
    SUB_0 = char(8320);  % ₀
    OMEGA = char(969);   % ω
    ZETA  = char(950);   % ζ
    CDOT  = char(183);   % ·

    if order == 1
        K = params(1); wn = params(2);
        txt = sprintf('H(s) = (%.4g %s %.4g) / (s + %.4g)', K, CDOT, wn, wn);
    elseif order == 2
        K = params(1); wn = params(2); zeta = params(3);
        txt = sprintf('H(s) = (%.4g %s %.4g%s) / (s%s + 2%s%.4g%s%.4g%ss + %.4g%s)', ...
                      K, CDOT, wn, SS_2, ...
                      SS_2, CDOT, zeta, CDOT, wn, CDOT, wn, SS_2);
    else
        K = params(1);
        % Build polynomial string s^n + a_{n-1}*s^{n-1} + ... + a0
        parts = {};
        if order == 3
            parts{end+1} = ['s' SS_3];
        elseif order == 4
            parts{end+1} = ['s' SS_4];
        else
            parts{end+1} = sprintf('s^%d', order);
        end
        for k = 1:order
            pwr = order - k;
            coef = params(k+1);
            if pwr == 0
                term = sprintf('%.4g', coef);
            elseif pwr == 1
                term = sprintf('%.4g%ss', coef, CDOT);
            elseif pwr == 2
                term = sprintf('%.4g%ss%s', coef, CDOT, SS_2);
            elseif pwr == 3
                term = sprintf('%.4g%ss%s', coef, CDOT, SS_3);
            else
                term = sprintf('%.4g%ss^%d', coef, CDOT, pwr);
            end
            parts{end+1} = term; %#ok<AGROW>
        end
        txt = sprintf('H(s) = (%.4g %s %.4g) / (%s)', ...
                      K, CDOT, params(end), strjoin(parts, ' + '));
    end
end
