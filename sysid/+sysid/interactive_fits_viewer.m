function interactive_fits_viewer(frf, lm_fit, advanced, fit_nlhw, fit_narx, ...
                                 amp_mm, in_role, out_role)
% INTERACTIVE_FITS_VIEWER  Bode plot of all fitted models with checkboxes
% to toggle each curve on/off. Lets you isolate which models you want
% visible before exporting a slide-ready screenshot.
%
%   sysid.interactive_fits_viewer(frf, lm_fit, advanced, fit_nlhw, fit_narx, ...
%                                 amp_mm, in_role, out_role)
%
% Inputs match plot_advanced_fits' signature. NLHW and NARX are accepted
% for completeness but only appear as a "(time-domain only)" note in the
% checkbox panel — they don't have a Bode representation.

    if nargin < 8, out_role = ''; end
    if nargin < 7, in_role  = ''; end

    fig = uifigure('Name','Step 5 — Interactive fit viewer', ...
                    'Position',[80 50 1320 760]);
    layout = uigridlayout(fig, [1 2]);
    layout.ColumnWidth = {'4x','1.3x'};

    % --- Plot panel ---
    plotPanel = uipanel(layout,'BorderType','none');
    pl = uigridlayout(plotPanel, [2 1]);
    pl.RowHeight = {'1x','1x'};
    axMag = uiaxes(pl);
    axPh  = uiaxes(pl);

    set(axMag,'XScale','log','YScale','log');
    set(axPh,'XScale','log');
    hold(axMag,'on'); hold(axPh,'on');
    grid(axMag,'on'); grid(axPh,'on');

    % Collect all lines we'll draw. Each entry has display name and the
    % two line handles ([mag, phase]).
    LH = struct();  % LH.<key> = struct('name', '...', 'lines', [hMag, hPh])

    methods_keys = {};
    if ~isempty(advanced)
        methods_keys = fieldnames(advanced);
    end

    nColors = 1 + 1 + numel(methods_keys);   % data + LM + each advanced
    cmap = lines(max(nColors, 2));
    color_idx = 1;

    % --- Welch data ---
    hMag = plot(axMag, frf.f, frf.mag, '.-', 'Color',[0.20 0.40 0.70], ...
                'MarkerSize',8, 'LineWidth',0.5, 'DisplayName','Welch H_1 (data)');
    hPh  = plot(axPh,  frf.f, rad2deg(frf.phase), '.-', 'Color',[0.20 0.40 0.70], ...
                'MarkerSize',8, 'LineWidth',0.5, 'DisplayName','Welch H_1 (data)');
    LH.data = struct('name','Welch H_1 (data)','lines',[hMag, hPh]);

    % --- LM 4th from Step 4 ---
    color = cmap(color_idx,:); color_idx = color_idx + 1;
    hMag = plot(axMag, frf.f, abs(lm_fit.H_pred), '--', 'Color',color, ...
                'LineWidth',1.8, 'DisplayName','LM 4th (Step 4)');
    hPh  = plot(axPh,  frf.f, rad2deg(unwrap(angle(lm_fit.H_pred))), '--', ...
                'Color',color, 'LineWidth',1.8, 'DisplayName','LM 4th (Step 4)');
    LH.lm4 = struct('name','LM 4th (Step 4)','lines',[hMag, hPh]);

    % --- Each advanced fit ---
    for k = 1:numel(methods_keys)
        nm = methods_keys{k};
        af = advanced.(nm);
        color = cmap(color_idx,:); color_idx = color_idx + 1;
        hMag = plot(axMag, frf.f, abs(af.H_pred), '-', 'Color',color, ...
                    'LineWidth',1.6, 'DisplayName',af.name);
        hPh  = plot(axPh,  frf.f, rad2deg(unwrap(angle(af.H_pred))), '-', ...
                    'Color',color, 'LineWidth',1.6, 'DisplayName',af.name);
        LH.(nm) = struct('name',af.name,'lines',[hMag, hPh]);
    end

    title(axMag, sprintf('Magnitude  ·  %s → %s  ·  BLA @ amp = %.1f mm', ...
        in_role, out_role, amp_mm),'Interpreter','none');
    title(axPh,  'Phase');
    ylabel(axMag,'|H|'); ylabel(axPh,'phase (deg)');
    xlabel(axPh,'frequency (Hz)');
    legend(axMag,'Location','best','FontSize',9);
    legend(axPh, 'Location','best','FontSize',9);

    % --- Control panel: header + checkboxes + bulk actions + save ---
    ctrlPanel = uipanel(layout,'Title','Show / hide fits','FontWeight','bold');

    keys = fieldnames(LH);
    nBoxes = numel(keys);
    % rows: header, [nBoxes checkboxes], spacer, "all on", "all off",
    %       spacer, save-as-png, status
    gridRows = num2cell([10, repmat(28, 1, nBoxes), 10, 30, 30, 10, 36, 30]);
    cl = uigridlayout(ctrlPanel, [numel(gridRows), 1]);
    cl.RowHeight = gridRows;

    uilabel(cl,'Text','','Visible','off');   % header spacer
    cboxes = gobjects(1, nBoxes);
    for k = 1:nBoxes
        ky = keys{k};
        cb = uicheckbox(cl, 'Text', LH.(ky).name, 'Value', true);
        cb.ValueChangedFcn = @(src,~) toggleLines(LH.(ky).lines, src.Value);
        cboxes(k) = cb;
    end
    uilabel(cl,'Text','','Visible','off');   % spacer

    uibutton(cl,'Text','Show all','ButtonPushedFcn',@(~,~) bulkSet(true));
    uibutton(cl,'Text','Hide all (except data)','ButtonPushedFcn',@(~,~) bulkSet(false));
    uilabel(cl,'Text','','Visible','off');   % spacer
    uibutton(cl,'Text','Save current view as PNG...', ...
                  'BackgroundColor',[0.85 0.95 0.85], ...
                  'ButtonPushedFcn',@onSavePNG);
    statusLbl = uilabel(cl,'Text','','FontAngle','italic','FontSize',10);

    % --- Note about time-domain-only models ---
    note = {};
    if ~isempty(fit_nlhw)
        note{end+1} = '• NLHW (time-domain) — see Step 6 VAF bars';
    end
    if ~isempty(fit_narx)
        note{end+1} = '• NARX (time-domain) — see Step 6 VAF bars';
    end
    if ~isempty(note)
        statusLbl.Text = strjoin(note, sprintf('\n'));
    end

    % ============================ callbacks ============================
    function toggleLines(lineHandles, isVisible)
        vis = 'off';
        if isVisible, vis = 'on'; end
        for kk = 1:numel(lineHandles)
            if isvalid(lineHandles(kk))
                lineHandles(kk).Visible = vis;
            end
        end
    end

    function bulkSet(showAll)
        for kk = 1:nBoxes
            if strcmp(keys{kk},'data')
                % Always keep data visible regardless of "hide all"
                cboxes(kk).Value = true;
                toggleLines(LH.data.lines, true);
            else
                cboxes(kk).Value = showAll;
                toggleLines(LH.(keys{kk}).lines, showAll);
            end
        end
    end

    function onSavePNG(~,~)
        default_name = sprintf('step5_view_amp%dmm.png', round(amp_mm));
        [fn, fp] = uiputfile({'*.png','PNG files'}, ...
                             'Save current view as...', default_name);
        if isequal(fn, 0), return; end
        try
            exportgraphics(fig, fullfile(fp, fn), 'Resolution', 200);
            statusLbl.Text = sprintf('Saved: %s', fn);
        catch ME
            statusLbl.Text = sprintf('Save failed: %s', ME.message);
        end
    end
end
