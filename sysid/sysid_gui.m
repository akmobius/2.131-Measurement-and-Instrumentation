function sysid_gui()
% SYSID_GUI  Stage-by-stage system-ID GUI with presentation-quality plots.
%
% Workflow (one button per stage):
%   1) Load & Plot Raw       — picks the CSV, plots raw input + output
%   2) Resample/Filter/Trim  — runs preprocess, plots before vs after
%   3) FRF + Parametric Fit  — Welch H1 + coh^2 + LM fit overlay
%   4) Validate              — prediction vs measured on held-out half
%
% Each stage saves its figure to <csv_folder>/results/ so the figures can
% drop straight into a slide deck.

    addpath(fileparts(mfilename('fullpath')));

    % ---- state ----
    S = struct();
    S.csv_path = '';
    S.cols     = {};
    S.plot_titles = struct('step1','','step2','','step3','','step4','','step5','','step6','');
    S.role_choices = {'(ignore)','time', ...
                      'piston_pos','piston_vel', ...
                      'inlet_air_p','inlet_air_q','inlet_air_q_theory', ...
                      'outlet_water_p','outlet_water_q'};
    S.uni     = [];   % resampled struct
    S.pre     = [];   % preprocessed struct
    S.frf     = [];
    S.fit     = [];
    S.dwell_pts = [];
    S.ir      = [];
    S.out_dir = '';

    % ---- figure ----
    fig = uifigure('Name','SysID Setup', 'Position', [200 25 600 1020]);
    g = uigridlayout(fig, [24 4]);
    g.RowHeight   = {28,28,28,'1x',28,28,28,28,28,28,28, ...
                     8, 36,36,36,36,36, 36, 36, ...
                     8, 28, 36, 28, 36};
    g.ColumnWidth = {130,'1x',130,'1x'};

    % --- file row ---
    uilabel(g,'Text','CSV file:','HorizontalAlignment','right');
    pathFld = uieditfield(g,'text','Editable','off');
    pathFld.Layout.Column = [2 3];
    uibutton(g,'Text','Browse...','ButtonPushedFcn', @onBrowse);

    % --- time col ---
    uilabel(g,'Text','Time column:','HorizontalAlignment','right');
    timeDD = uidropdown(g,'Items',{''},'Value','');
    timeDD.Layout.Column = [2 4];

    % --- mapping help row ---
    uilabel(g,'Text','Channel mapping:','HorizontalAlignment','right');
    tip = uilabel(g,'Text', ...
        'Set each CSV column to a role, or "(ignore)". Time column is set above.', ...
        'FontAngle','italic');
    tip.Layout.Column = [2 4];

    % --- mapping table ---
    mapTbl = uitable(g, ...
        'ColumnName',{'CSV column','Role'}, ...
        'ColumnEditable',[false true], ...
        'ColumnFormat',{'char', S.role_choices}, ...
        'Data',cell(0,2), ...
        'RowName',{});
    mapTbl.Layout.Row    = 4;
    mapTbl.Layout.Column = [1 4];

    % --- I/O pair ---
    uilabel(g,'Text','Input role:','HorizontalAlignment','right');
    inDD  = uidropdown(g,'Items', ...
                        {'piston_pos','piston_vel', ...
                         'inlet_air_p','inlet_air_q','inlet_air_q_theory', ...
                         'outlet_water_p','outlet_water_q'}, ...
                        'Value','piston_pos');
    uilabel(g,'Text','Output role:','HorizontalAlignment','right');
    outDD = uidropdown(g,'Items', ...
                        {'outlet_water_q','outlet_water_p', ...
                         'inlet_air_q','inlet_air_q_theory','inlet_air_p', ...
                         'piston_pos','piston_vel'}, ...
                        'Value','outlet_water_q');

    % --- excitation + fs ---
    uilabel(g,'Text','Excitation:','HorizontalAlignment','right');
    excDD = uidropdown(g,'Items',{'sine_sweep','broadband'},'Value','sine_sweep');
    uilabel(g,'Text','Resample fs (Hz):','HorizontalAlignment','right');
    fsFld = uieditfield(g,'numeric','Value',200,'Limits',[1 1e5]);

    % --- preprocess ---
    uilabel(g,'Text','LP cutoff (Hz):','HorizontalAlignment','right');
    lpFld = uieditfield(g,'numeric','Value',25,'Limits',[0 1e5]);
    uilabel(g,'Text','Crop start t (s):','HorizontalAlignment','right');
    cropStartFld = uieditfield(g,'numeric','Value',0,'Limits',[0 1e4]);

    uilabel(g,'Text','Crop end t (s):','HorizontalAlignment','right');
    cropEndFld = uieditfield(g,'numeric','Value',0,'Limits',[0 1e4]);

    % --- fit ---
    uilabel(g,'Text','Model order:','HorizontalAlignment','right');
    ordFld = uieditfield(g,'numeric','Value',2,'Limits',[1 8],'RoundFractionalValues','on');
    uilabel(g,'Text','Train fraction:','HorizontalAlignment','right');
    splitFld = uieditfield(g,'numeric','Value',0.5,'Limits',[0.1 0.9]);

    titlesBtn = uibutton(g,'Text','Edit plot titles...', ...
        'ButtonPushedFcn',@onEditTitles);
    titlesBtn.Layout.Column = [3 4];

    % --- status ---
    statusLbl = uilabel(g,'Text','Pick a CSV to begin.','FontAngle','italic');
    statusLbl.Layout.Row    = 11;
    statusLbl.Layout.Column = [1 4];

    % --- spacer ---
    uilabel(g,'Text','');  % row 12 spacer

    % --- stage buttons ---
    btn1 = uibutton(g,'Text','Step 1 — Load & plot raw data', ...
        'ButtonPushedFcn',@onStep1);
    btn1.Layout.Row = 13; btn1.Layout.Column = [1 4];

    btn2 = uibutton(g,'Text','Step 2 — Resample, filter, trim', ...
        'Enable','off','ButtonPushedFcn',@onStep2);
    btn2.Layout.Row = 14; btn2.Layout.Column = [1 4];

    btn3 = uibutton(g,'Text','Step 3 — Input/output spectrum (FFT)', ...
        'Enable','off','ButtonPushedFcn',@onStep3);
    btn3.Layout.Row = 15; btn3.Layout.Column = [1 4];

    btn4 = uibutton(g,'Text','Step 4 — Bode plot + parametric fit', ...
        'Enable','off','ButtonPushedFcn',@onStep4);
    btn4.Layout.Row = 16; btn4.Layout.Column = [1 4];

    btnExplorer = uibutton(g,'Text','     Step 4 option: Manual fit explorer (tune K, ωₙ, ζ by hand)', ...
        'Enable','off','ButtonPushedFcn',@onExplorer, ...
        'BackgroundColor',[0.92 0.92 1.00], 'HorizontalAlignment','left');
    btnExplorer.Layout.Row = 17; btnExplorer.Layout.Column = [1 4];

    btn5 = uibutton(g,'Text','Step 5 — Advanced fitting (tfest / procest / NLHW, with physical models)', ...
        'Enable','off','ButtonPushedFcn',@onStep5_advanced, ...
        'BackgroundColor',[1.00 0.90 0.75]);
    btn5.Layout.Row = 18; btn5.Layout.Column = [1 4];

    btn6 = uibutton(g,'Text','Step 6 — Validate on held-out half', ...
        'Enable','off','ButtonPushedFcn',@onStep6_validate, ...
        'BackgroundColor',[0.85 0.95 0.85]);
    btn6.Layout.Row = 19; btn6.Layout.Column = [1 4];

    % --- spacer row 20 ---
    spacerLbl = uilabel(g,'Text',''); spacerLbl.Layout.Row = 20;

    % --- Nonlinearity / amplitude sweep section ---
    swpHdr = uilabel(g,'Text','Nonlinearity sweep — collect BLAs across conditions:', ...
        'FontWeight','bold');
    swpHdr.Layout.Row = 21; swpHdr.Layout.Column = [1 4];

    uilabel(g,'Text','Run label:','HorizontalAlignment','right');
    labelFld = uieditfield(g,'text','Value','80mm');
    labelFld.Layout.Column = 2;
    addBtn = uibutton(g,'Text','Add current fit to set', ...
        'Enable','off','ButtonPushedFcn',@onAddToSet);
    addBtn.Layout.Column = [3 4];

    setSummaryLbl = uilabel(g,'Text','set: empty','FontAngle','italic');
    setSummaryLbl.Layout.Row = 23; setSummaryLbl.Layout.Column = [1 4];

    plotBtn = uibutton(g,'Text','Plot nonlinearity comparison', ...
        'Enable','off','ButtonPushedFcn',@onPlotSet);
    plotBtn.Layout.Column = [1 3];
    clearBtn = uibutton(g,'Text','Clear set','ButtonPushedFcn',@onClearSet);
    clearBtn.Layout.Column = 4;

    % comparison set storage
    S.set = struct('label',{},'amp_mm',{},'frf',{},'fit',{},'csv',{}, ...
                   'vaf',{},'thd_pct',{});

    % ===================== callbacks =====================

    function onBrowse(~,~)
        [f, p] = uigetfile({'*.csv','CSV files'}, ...
                           'Select data CSV(s) — multi-select OK', ...
                           'MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f = {f}; end             % normalize to cellstr
        paths = cellfun(@(x) fullfile(p,x), f, 'uni', 0);
        S.csv_paths = paths;
        S.csv_path  = paths{1};                % keep for back-compat
        pathFld.Value = strjoin(f, ' ; ');

        % Read each file's columns; build union with file-of-origin tags
        all_cols = {};
        col_origin = {};   % per-column source filename (for the table tooltip)
        time_candidates = {};
        for kf = 1:numel(paths)
            try
                T = readtable(paths{kf},'VariableNamingRule','preserve');
            catch ME
                uialert(fig, sprintf('Error reading %s: %s', f{kf}, ME.message), ...
                        'CSV read error'); return;
            end
            cols = T.Properties.VariableNames;
            for j = 1:numel(cols)
                if ~ismember(cols{j}, all_cols)
                    all_cols{end+1} = cols{j}; %#ok<AGROW>
                    col_origin{end+1} = f{kf}; %#ok<AGROW>
                end
                if any(strcmpi(cols{j}, {'time','time_s','time_ms'})) ...
                        && ~ismember(cols{j}, time_candidates)
                    time_candidates{end+1} = cols{j}; %#ok<AGROW>
                end
            end
        end
        S.cols = all_cols;

        % Time-column dropdown — common name expected across files
        timeDD.Items = all_cols;
        if ~isempty(time_candidates)
            timeDD.Value = time_candidates{1};
        else
            timeDD.Value = all_cols{1};
        end

        % Mapping table — auto-guess role for every column from every file
        guessed = cell(numel(all_cols), 2);
        for k = 1:numel(all_cols)
            guessed{k,1} = sprintf('%s   [%s]', all_cols{k}, col_origin{k});
            guessed{k,2} = guess_role(all_cols{k});
        end
        mapTbl.Data = guessed;
        S.out_dir = fullfile(fileparts(S.csv_path), 'results');
        if ~exist(S.out_dir,'dir'), mkdir(S.out_dir); end
        statusLbl.Text = sprintf('Loaded %d file(s), %d unique columns.', ...
                                  numel(paths), numel(all_cols));
        % Reset downstream state and disable later steps
        S.uni=[]; S.pre=[]; S.frf=[]; S.fit=[]; S.dwell_pts=[]; S.ir=[];
        S.fit_nlhw = [];
        btn2.Enable='off'; btn3.Enable='off'; btn4.Enable='off';
        btn5.Enable='off'; btn6.Enable='off'; btnExplorer.Enable='off';
    end

    function cfg = build_csv_cfg()
        if isfield(S,'csv_paths') && ~isempty(S.csv_paths)
            cfg.files = S.csv_paths;
        else
            cfg.files = {S.csv_path};
        end
        cfg.time_col = timeDD.Value;
        cfg.roles    = struct();
        D = mapTbl.Data;
        for k = 1:size(D,1)
            col_display = D{k,1};
            role        = D{k,2};
            if strcmp(role,'(ignore)') || strcmp(role,'time'), continue; end
            % Display string is "colname   [filename]"; strip the suffix
            col = regexprep(col_display, '\s+\[.*\]\s*$', '');
            cfg.roles.(matlab.lang.makeValidName(col)) = role;
        end
    end

    % --------------- Step 1: raw ---------------
    function onStep1(~,~)
        if isempty(S.csv_path)
            uialert(fig,'Pick a CSV first.','No file'); return;
        end
        try
            data = sysid.load_csv(build_csv_cfg());
        catch ME, uialert(fig, ME.message, 'Load error'); return;
        end
        roles_assigned = setdiff(fieldnames(data), {'fs_native'});
        if ~ismember(inDD.Value, roles_assigned) || ~ismember(outDD.Value, roles_assigned)
            uialert(fig,'Input/output role is not assigned to any column.','Bad mapping'); return;
        end

        plot_raw(data, inDD.Value, outDD.Value, ...
                 fullfile(S.out_dir,'step1_raw.png'), S.plot_titles.step1);
        statusLbl.Text = 'Step 1 done. Saved step1_raw.png.';
        btn2.Enable='on';
    end

    % --------------- Step 2: preprocess ---------------
    function onStep2(~,~)
        try
            data = sysid.load_csv(build_csv_cfg());
        catch ME, uialert(fig, ME.message, 'Load error'); return;
        end

        % Per-file crop+align: output channel cropped to its activity
        % window, channels from any other file (e.g. synthesized input)
        % cropped to a matching duration starting from their own t=0.
        t_lo = cropStartFld.Value;
        t_hi = cropEndFld.Value;
        crop_msg = '';
        if t_lo > 0 || t_hi > 0
            try
                data = sysid.crop_align(data, outDD.Value, t_lo, t_hi);
                crop_msg = sprintf('  [output cropped %.2f-%.2f s; input matched]', ...
                                    t_lo, max(t_hi, 0));
            catch ME
                uialert(fig, ME.message, 'Crop/align failed'); return;
            end
        end

        S.uni = sysid.resample_uniform(data, fsFld.Value);
        fprintf(['[Step 2] resampled fs=%.0f Hz, %d samples, ' ...
                 'duration=%.2f s, channels=%s\n'], ...
                 S.uni.fs, numel(S.uni.t), S.uni.t(end), strjoin(S.uni.roles, ', '));

        opts = struct('detrend','mean', ...
                      'lp_cutoff', lpFld.Value, ...
                      'lp_order',  4, ...
                      'notch_f0',  []);
        S.pre = sysid.preprocess(S.uni, opts);

        plot_preprocess(S.uni, S.pre, inDD.Value, outDD.Value, ...
                        fullfile(S.out_dir,'step2_preprocess.png'), S.plot_titles.step2);
        statusLbl.Text = sprintf('Step 2 done. Saved step2_preprocess.png.%s  Final duration = %.2f s.', ...
            crop_msg, S.pre.t(end));
        btn3.Enable='on';
    end

    % --------------- Step 3: spectrum (FFT) ---------------
    function onStep3(~,~)
        if isempty(S.pre), onStep2(); end
        u = S.pre.(inDD.Value);  y = S.pre.(outDD.Value);
        fs = S.pre.fs;

        plot_spectrum(u, y, fs, inDD.Value, outDD.Value, ...
                      fullfile(S.out_dir, 'step3_spectrum.png'), S.plot_titles.step3);
        statusLbl.Text = 'Step 3 done. Saved step3_spectrum.png.';
        btn4.Enable = 'on';
    end

    % --------------- Step 4: FRF + fit ---------------
    function onStep4(~,~)
        if isempty(S.pre), onStep2(); end
        u = S.pre.(inDD.Value); y = S.pre.(outDD.Value);
        t = S.pre.t;             fs = S.pre.fs;
        N_tr = round(splitFld.Value*numel(t));
        u_tr = u(1:N_tr); y_tr = y(1:N_tr); t_tr = t(1:N_tr);
        S.tr = struct('u',u_tr,'y',y_tr,'t',t_tr,'N',N_tr);

        % Pick nfft so we get ~6-8 averaging segments. Cap at 4096, floor at 256.
        nfft_target = 2^floor(log2(numel(u_tr)/4));
        nfft_target = min(4096, max(256, nfft_target));
        wopts = struct('nfft', nfft_target, 'overlap', 0.5, ...
                       'fmin', 0.05, 'fmax', min(25, fs/2 - 1));

        % --- Reproducibility check: hash the inputs and outputs and
        % compare against the previous run. Any difference flags
        % a real nondeterminism bug.
        u_hash = mean(u_tr) + std(u_tr)*1e6 + numel(u_tr);
        y_hash = mean(y_tr) + std(y_tr)*1e6 + numel(y_tr);
        fprintf(['[Step 4] N_train=%d, fs=%.0f Hz, nfft=%d, ' ...
                 'bin_spacing=%.3f Hz, fit_order=%d\n'], ...
                 numel(u_tr), fs, nfft_target, fs/nfft_target, ordFld.Value);
        fprintf('[Step 4] u_tr hash=%.10g   y_tr hash=%.10g\n', u_hash, y_hash);
        if isfield(S,'last_u_hash') && ~isempty(S.last_u_hash)
            du = u_hash - S.last_u_hash;
            dy = y_hash - S.last_y_hash;
            if abs(du) > 1e-9 || abs(dy) > 1e-9
                fprintf(2,['[Step 4] *** INPUTS DIFFER from previous run *** ' ...
                           'u_diff=%.3g y_diff=%.3g\n'], du, dy);
            else
                fprintf('[Step 4] inputs identical to previous run.\n');
            end
        end
        S.last_u_hash = u_hash;
        S.last_y_hash = y_hash;

        S.frf = sysid.frf_welch(u_tr, y_tr, fs, wopts);

        frf_hash = sum(S.frf.mag) + sum(S.frf.coh2)*1e3;
        fprintf('[Step 4] frf hash=%.10g  (mag sum=%.4g, coh2 sum=%.4g)\n', ...
                frf_hash, sum(S.frf.mag), sum(S.frf.coh2));
        if isfield(S,'last_frf_hash') && ~isempty(S.last_frf_hash)
            df = frf_hash - S.last_frf_hash;
            if abs(df) > 1e-9
                fprintf(2,['[Step 4] *** FRF DIFFERS from previous run *** ' ...
                           'frf_diff=%.6g\n'], df);
            else
                fprintf('[Step 4] FRF identical to previous run.\n');
            end
        end
        S.last_frf_hash = frf_hash;

        S.dwell_pts = [];
        if strcmpi(excDD.Value,'sine_sweep')
            segs = sysid.segment_sine_sweep(t_tr, u_tr);
            S.dwell_pts = sysid.frf_sine_dwell(u_tr, y_tr, fs, segs);
        end

        S.ir = sysid.impulse_svd(u_tr, y_tr, fs, ...
                struct('L',round(2.0*fs),'sv_keep',0.95));

        S.fit = sysid.fit_param_tf(S.frf, ...
                struct('order',ordFld.Value,'weight','coh2', ...
                       'fmin',wopts.fmin,'fmax',wopts.fmax));

        plot_fit(S.frf, S.fit, S.dwell_pts, S.ir, inDD.Value, outDD.Value, ...
                 fullfile(S.out_dir,'step4_fit.png'), S.plot_titles.step4);

        statusLbl.Text = sprintf('Step 4 done. %s. Saved step4_fit.png.', ...
            fit_summary(S.fit));
        btn5.Enable='on';
        btn6.Enable='on';
        btnExplorer.Enable='on';
        addBtn.Enable='on';     % can now add this BLA to the comparison set
        S.last_vaf = NaN;       % filled in by Step 5
    end

    % --------------- Step 5: Advanced parametric fitting ---------------
    function onStep5_advanced(~,~)
        if isempty(S.fit), onStep4(); end
        u = S.pre.(inDD.Value); y = S.pre.(outDD.Value);
        t = S.pre.t;             fs = S.pre.fs;
        N_tr = S.tr.N;
        u_tr = u(1:N_tr);    y_tr = y(1:N_tr);

        % Detect the BLA amplitude from the AC swing of the training input
        amp_mm = (max(u_tr) - min(u_tr)) / 2;

        statusLbl.Text = 'Step 5 — fitting multiple parametric models (tfest, procest, NLHW)...';
        drawnow;

        % --- Run all the linear/structured fits (tfest, procest, etc.) ---
        try
            S.advanced = sysid.fit_advanced(S.frf, u_tr, y_tr, fs, ...
                struct('amplitude_mm', amp_mm));
        catch ME
            is_toolbox_missing = strcmp(ME.identifier,'MATLAB:UndefinedFunction');
            if is_toolbox_missing
                uialert(fig, ['System Identification Toolbox required for ' ...
                    'tfest / procest fitting. Error: ' ME.message], ...
                    'Toolbox missing');
            else
                uialert(fig, getReport(ME,'extended','hyperlinks','off'), ...
                    'Advanced fitting failed');
            end
            return;
        end

        % --- Also run NLHW as one of the methods ---
        S.fit_nlhw = [];
        try
            nlhw_order = min(2, max(1, ordFld.Value));
            nlhw_opts = struct('nb', nlhw_order, 'nf', nlhw_order, 'nk', 0, ...
                'input_nl','pwlinear','output_nl','unitgain');
            S.fit_nlhw = sysid.fit_hw(u_tr, y_tr, fs, nlhw_opts);
        catch ME
            fprintf('[Step 5] NLHW skipped: %s\n', ME.message);
        end

        % --- And run a truly-nonlinear NARX (black-box) ---
        % NARX isn't constrained to H(s) = N(s)/D(s) form; it can fit any
        % nonlinear input-output map. Useful when "fit the line, whatever
        % it is" is the goal — at the cost of losing physical meaning.
        S.fit_narx = [];
        try
            narx_opts = struct('na', 4, 'nb', 4, 'nk', 1, ...
                'nonlinearity','sigmoidnet', 'num_units', 10);
            S.fit_narx = sysid.fit_narx(u_tr, y_tr, fs, narx_opts);
        catch ME
            fprintf('[Step 5] NARX skipped: %s\n', ME.message);
        end

        % --- Static slide-ready plot (saves PNG with all curves shown) ---
        plot_advanced_fits(S.frf, S.fit, S.advanced, S.fit_nlhw, S.fit_narx, ...
            amp_mm, inDD.Value, outDD.Value, ...
            fullfile(S.out_dir, 'step5_advanced.png'), S.plot_titles.step5);

        % --- Interactive viewer with checkboxes to toggle each curve ---
        try
            sysid.interactive_fits_viewer(S.frf, S.fit, S.advanced, ...
                S.fit_nlhw, S.fit_narx, amp_mm, inDD.Value, outDD.Value);
        catch ME
            fprintf('[Step 5] Interactive viewer failed: %s\n', ME.message);
        end

        n_methods = numel(fieldnames(S.advanced)) + 1;  % +1 for the Step-4 LM
        if ~isempty(S.fit_nlhw), n_methods = n_methods + 1; end
        if ~isempty(S.fit_narx), n_methods = n_methods + 1; end
        statusLbl.Text = sprintf(['Step 5 done. Compared %d fits at amp=%.1f mm. ' ...
            'Static PNG saved; interactive viewer opened.'], n_methods, amp_mm);
    end

    % --------------- Step 6: Validate (compares all available fits) ---------------
    function onStep6_validate(~,~)
        if isempty(S.fit), onStep4(); end
        u = S.pre.(inDD.Value); y = S.pre.(outDD.Value);
        t = S.pre.t;             fs = S.pre.fs;
        N_tr = S.tr.N;
        u_va = u(N_tr+1:end);  y_va = y(N_tr+1:end);
        t_va = t(N_tr+1:end) - t(N_tr+1);

        % Always include the Step 4 LM fit
        preds = struct();
        preds.lm4 = struct( ...
            'name','LM 4th (Step 4)', ...
            'y',   sysid.sim_ct(S.fit.num, S.fit.den, u_va, fs));
        preds.lm4.vaf = sysid.score_vaf(y_va, preds.lm4.y);

        % Add advanced fits (if Step 5 was run)
        if isfield(S,'advanced') && ~isempty(S.advanced)
            fnames = fieldnames(S.advanced);
            for k = 1:numel(fnames)
                af = S.advanced.(fnames{k});
                try
                    y_pred = sysid.sim_ct(af.num, af.den, u_va, fs);
                    % Apply delay if present (simple sample shift)
                    if isfield(af,'delay') && af.delay > 0
                        dshift = round(af.delay * fs);
                        if dshift < numel(y_pred)
                            y_pred = [zeros(dshift,1); y_pred(1:end-dshift)];
                        end
                    end
                    preds.(fnames{k}) = struct( ...
                        'name', af.name, ...
                        'y',    y_pred);
                    preds.(fnames{k}).vaf = sysid.score_vaf(y_va, y_pred);
                catch ME
                    fprintf('[Step 6] %s sim failed: %s\n', af.name, ME.message);
                end
            end
        end

        % Add NLHW (if Step 5 produced one)
        if isfield(S,'fit_nlhw') && ~isempty(S.fit_nlhw)
            try
                y_nlhw = sysid.sim_hw(S.fit_nlhw.sys, u_va, fs);
                preds.nlhw = struct('name','NLHW', 'y', y_nlhw, ...
                                    'vaf', sysid.score_vaf(y_va, y_nlhw));
            catch ME
                fprintf('[Step 6] NLHW sim failed: %s\n', ME.message);
            end
        end

        % Add NARX (if Step 5 produced one)
        if isfield(S,'fit_narx') && ~isempty(S.fit_narx)
            try
                y_narx = sysid.sim_narx(S.fit_narx.sys, u_va, fs);
                preds.narx = struct('name','NARX (black-box)', 'y', y_narx, ...
                                    'vaf', sysid.score_vaf(y_va, y_narx));
            catch ME
                fprintf('[Step 6] NARX sim failed: %s\n', ME.message);
            end
        end

        % Compute AIC for the linear fit (used for the consolidated summary)
        aic_lm = sysid.score_aic(y_va - preds.lm4.y, numel(S.fit.params));

        plot_validate_multi(t_va, y_va, preds, outDD.Value, ...
            fullfile(S.out_dir, 'step6_validation.png'), S.plot_titles.step6);

        % Save results
        res = struct('frf',S.frf,'fit',S.fit,'ir',S.ir,'dwell_pts',S.dwell_pts, ...
                     'preds', preds, ...
                     'vaf_validation', preds.lm4.vaf, ...
                     'aic_validation', aic_lm);
        if isfield(S,'advanced'), res.advanced = S.advanced; end
        if isfield(S,'fit_nlhw'), res.fit_nlhw = S.fit_nlhw; end
        save(fullfile(S.out_dir,'results.mat'),'-struct','res');
        S.last_vaf = preds.lm4.vaf;

        % Find best model by VAF
        best_name = 'LM 4th'; best_vaf = preds.lm4.vaf;
        f = fieldnames(preds);
        for k = 1:numel(f)
            if preds.(f{k}).vaf > best_vaf
                best_vaf = preds.(f{k}).vaf;
                best_name = preds.(f{k}).name;
            end
        end

        statusLbl.Text = sprintf('Step 6 done. LM4 VAF=%.1f%%   best=%s (%.1f%%). Saved step6_validation.png + results.mat.', ...
            preds.lm4.vaf, best_name, best_vaf);
    end

    % --------------- Manual fit explorer ---------------
    function onExplorer(~,~)
        if isempty(S.frf)
            uialert(fig,'Run Step 4 first to compute the FRF.','No FRF available');
            return;
        end
        try
            sysid.manual_fit_explorer(S.frf, S.fit);
            statusLbl.Text = 'Manual fit explorer opened in a new window.';
        catch ME
            uialert(fig, getReport(ME,'extended','hyperlinks','off'), ...
                'Explorer failed');
        end
    end

    % --------------- Plot title editor ---------------
    function onEditTitles(~,~)
        prompts  = {'Step 1 (raw data):', ...
                    'Step 2 (preprocessed):', ...
                    'Step 3 (spectrum):', ...
                    'Step 4 (Bode + parametric fit):', ...
                    'Step 5 (advanced fitting):', ...
                    'Step 6 (validation):'};
        defaults = {S.plot_titles.step1, S.plot_titles.step2, ...
                    S.plot_titles.step3, S.plot_titles.step4, ...
                    S.plot_titles.step5, S.plot_titles.step6};
        dims = repmat([1 80], 6, 1);
        ans_ = inputdlg(prompts, 'Edit plot titles  (blank = use default)', ...
                        dims, defaults);
        if isempty(ans_), return; end
        S.plot_titles.step1 = ans_{1};
        S.plot_titles.step2 = ans_{2};
        S.plot_titles.step3 = ans_{3};
        S.plot_titles.step4 = ans_{4};
        S.plot_titles.step5 = ans_{5};
        S.plot_titles.step6 = ans_{6};
        statusLbl.Text = 'Plot titles updated. Re-run any step to apply.';
    end

    % --------------- Nonlinearity sweep callbacks ---------------
    function onAddToSet(~,~)
        if isempty(S.fit)
            uialert(fig,'Run Step 4 first to fit a model.','No fit'); return;
        end
        u_full = S.pre.(inDD.Value); y_full = S.pre.(outDD.Value);
        amp_mm = (max(u_full) - min(u_full)) / 2;     % half peak-to-peak
        thd    = compute_thd(u_full, y_full, S.pre.fs);

        entry.label   = labelFld.Value;
        entry.amp_mm  = amp_mm;
        entry.frf     = S.frf;
        entry.fit     = S.fit;
        entry.csv     = S.csv_path;
        if isfield(S,'last_vaf') && ~isnan(S.last_vaf)
            entry.vaf = S.last_vaf;
        else
            entry.vaf = NaN;
        end
        entry.thd_pct = thd;
        S.set(end+1) = entry;

        update_set_label();
        plotBtn.Enable = 'on';
    end

    function onPlotSet(~,~)
        if isempty(S.set)
            uialert(fig,'Set is empty.','Nothing to plot'); return;
        end
        plot_set_summary(S.set, inDD.Value, outDD.Value, ...
                         fullfile(S.out_dir, 'nonlinearity_summary.png'));
        statusLbl.Text = sprintf(['Saved nonlinearity_summary.png with %d ' ...
                                  'conditions.'], numel(S.set));
    end

    function onClearSet(~,~)
        S.set = struct('label',{},'amp_mm',{},'frf',{},'fit',{}, ...
                       'csv',{},'vaf',{},'thd_pct',{});
        update_set_label();
        plotBtn.Enable = 'off';
    end

    function update_set_label()
        if isempty(S.set)
            setSummaryLbl.Text = 'set: empty';
        else
            parts = arrayfun(@(e) sprintf('%s (%.1f mm)', e.label, e.amp_mm), ...
                             S.set, 'uni', 0);
            setSummaryLbl.Text = sprintf('set (%d): %s', numel(S.set), strjoin(parts,', '));
        end
    end
end

% ============================================================================
%                        STAGE PLOT FUNCTIONS
% ============================================================================

function plot_raw(data, inRole, outRole, save_path, custom_title)
% Two stacked time-series panels: raw input + raw output.
    fig = figure('Color','w','Position',[80 80 980 520], 'Name','Step 1 — Raw data');
    tl  = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
    if nargin >= 5 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    else
        title(tl, 'Step 1 — Raw sensor data', 'FontSize',14, 'FontWeight','bold');
    end

    ax1 = nexttile;
    plot(ax1, data.(inRole).t, data.(inRole).y, '.', ...
         'Color',[0.10 0.45 0.80], 'MarkerSize',4);
    ylabel(ax1, label_for(inRole), 'Interpreter','none');
    title(ax1, sprintf('Input: %s   (native fs ≈ %.1f Hz)', ...
        inRole, 1/median(diff(data.(inRole).t))), 'Interpreter','none');

    ax2 = nexttile;
    plot(ax2, data.(outRole).t, data.(outRole).y, '.', ...
         'Color',[0.85 0.33 0.10], 'MarkerSize',4);
    ylabel(ax2, label_for(outRole), 'Interpreter','none');
    xlabel(ax2, 'time (s)');
    title(ax2, sprintf('Output: %s   (native fs ≈ %.1f Hz)', ...
        outRole, 1/median(diff(data.(outRole).t))), 'Interpreter','none');

    linkaxes([ax1 ax2], 'x');
    sysid.presentation_style(fig);
    if nargin >= 4 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function plot_preprocess(uni, pre, inRole, outRole, save_path, custom_title)
% Two panels: cleaned input + cleaned output (resampled, detrended,
% low-passed, trimmed).
    fig = figure('Color','w','Position',[80 80 1000 540], ...
                 'Name','Step 2 — Resampled & cleaned');
    tl = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
    if nargin >= 6 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14,'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf(['Step 2 — Resampled to %.0f Hz,  zero-phase Butterworth LPF, ' ...
            'mean removed,  startup trimmed'], pre.fs), ...
            'FontSize', 14, 'FontWeight','bold');
    end

    ax1 = nexttile;
    plot(ax1, pre.t, pre.(inRole), '.', 'Color',[0.10 0.45 0.80], 'MarkerSize',4);
    ylabel(ax1, label_for(inRole), 'Interpreter','none');
    title(ax1, sprintf('Input: %s', inRole), 'Interpreter','none');

    ax2 = nexttile;
    plot(ax2, pre.t, pre.(outRole), '.', 'Color',[0.85 0.33 0.10], 'MarkerSize',4);
    ylabel(ax2, label_for(outRole), 'Interpreter','none');
    xlabel(ax2, 'time (s)');
    title(ax2, sprintf('Output: %s', outRole), 'Interpreter','none');

    linkaxes([ax1 ax2], 'x');

    sysid.presentation_style(fig);
    if nargin >= 5 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function plot_spectrum(u, y, fs, inRole, outRole, save_path, custom_title)
% Single-sided amplitude spectra of input and output, log-x.
% Helps the audience see (a) where the trapezoid puts its energy
% (the harmonic comb) and (b) whether the output preserves only those
% frequencies (linear) or grows new ones (nonlinear distortion).

    N = numel(u);
    win = hann(N);
    U = fft(u .* win);  Y = fft(y .* win);
    f = (0:floor(N/2))' * (fs/N);
    Au = abs(U(1:numel(f))) * 2/sum(win);
    Ay = abs(Y(1:numel(f))) * 2/sum(win);

    fig = figure('Color','w','Position',[80 80 1100 600], ...
                 'Name','Step 3 — Input/output spectrum');
    tl = tiledlayout(fig, 2, 1, 'TileSpacing','compact','Padding','compact');
    if nargin >= 7 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14,'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf(['Step 3 — Single-sided amplitude spectrum   ' ...
                           '(record length %.1f s, fs = %.0f Hz)'], N/fs, fs), ...
            'FontSize',14,'FontWeight','bold');
    end

    fmin = 0.05;
    fmax = min(fs/2, 25);

    ax1 = nexttile;
    plot(ax1, f, Au, '.-', 'Color',[0.10 0.45 0.80], 'MarkerSize',6, 'LineWidth',0.4);
    set(ax1,'XScale','log','YScale','log');
    xlim(ax1, [fmin fmax]); grid(ax1,'on');
    ylabel(ax1, sprintf('|U(f)|  [%s]', label_for(inRole)),'Interpreter','none');
    title(ax1, sprintf('Input spectrum: %s', inRole), 'Interpreter','none');

    ax2 = nexttile;
    plot(ax2, f, Ay, '.-', 'Color',[0.85 0.33 0.10], 'MarkerSize',6, 'LineWidth',0.4);
    set(ax2,'XScale','log','YScale','log');
    xlim(ax2, [fmin fmax]); grid(ax2,'on');
    ylabel(ax2, sprintf('|Y(f)|  [%s]', label_for(outRole)),'Interpreter','none');
    xlabel(ax2,'frequency (Hz)');
    title(ax2, sprintf('Output spectrum: %s', outRole), 'Interpreter','none');

    linkaxes([ax1 ax2], 'x');

    sysid.presentation_style(fig);
    if nargin >= 6 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function plot_fit(frf, fit, dwell_pts, ir, inRole, outRole, save_path, custom_title)
% Bode (mag/phase/coh^2) with parametric overlay + dwell points,
% plus a small impulse-response inset panel on the right.
    fig = figure('Color','w','Position',[60 60 1180 760], ...
                 'Name','Step 3 — FRF + parametric fit');
    tl = tiledlayout(fig, 3, 4, 'TileSpacing','compact','Padding','compact');
    if nargin >= 8 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf('Step 4 — Non-parametric FRF + parametric fit:   %s → %s', ...
            inRole, outRole), 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    end

    % ---- Bode magnitude (rows 1, cols 1-3) ----
    ax1 = nexttile([1 3]); hold(ax1,'on'); set(ax1,'XScale','log','YScale','log');
    loglog(ax1, frf.f, frf.mag, '.-', 'Color',[0.20 0.40 0.70], ...
           'MarkerSize',8, 'LineWidth',0.4, 'DisplayName','Welch H_1');
    loglog(ax1, frf.f, abs(fit.H_pred), '--', 'Color',[0.85 0.10 0.10], ...
           'LineWidth',2.0, 'DisplayName','LM fit (model)');
    if ~isempty(dwell_pts)
        plot(ax1, [dwell_pts.f], [dwell_pts.mag], 'o', ...
             'Color','k','MarkerFaceColor','k','MarkerSize',7, ...
             'DisplayName','sine dwells');
    end
    ylabel(ax1, '|H|'); title(ax1,'Magnitude');
    legend(ax1,'Location','best');

    % ---- Impulse response (rows 1-2, col 4) ----
    ax_ir = nexttile([2 1]); hold(ax_ir,'on');
    plot(ax_ir, ir.t, ir.h, '.', 'Color',[0.20 0.55 0.30], 'MarkerSize',6);
    yline(ax_ir, 0, ':');
    title(ax_ir, sprintf('Impulse response\n(DC gain = %.3g)', ir.gain_dc));
    xlabel(ax_ir,'time (s)'); ylabel(ax_ir,'h(t)');

    % ---- Bode phase (row 2, cols 1-3) ----
    ax2 = nexttile([1 3]); hold(ax2,'on'); set(ax2,'XScale','log');
    semilogx(ax2, frf.f, rad2deg(frf.phase), '.-', 'Color',[0.20 0.40 0.70], ...
             'MarkerSize',8, 'LineWidth',0.4, 'DisplayName','Welch H_1');
    semilogx(ax2, frf.f, rad2deg(unwrap(angle(fit.H_pred))), '--', ...
             'Color',[0.85 0.10 0.10], 'LineWidth',2.0, 'DisplayName','LM fit (model)');
    if ~isempty(dwell_pts)
        plot(ax2, [dwell_pts.f], rad2deg([dwell_pts.phase]), 'o', ...
             'Color','k','MarkerFaceColor','k','MarkerSize',7, ...
             'DisplayName','sine dwells');
    end
    ylabel(ax2, 'phase (deg)'); title(ax2,'Phase');
    legend(ax2,'Location','best');

    % ---- Coherence² (row 3, cols 1-3) ----
    ax3 = nexttile([1 3]); hold(ax3,'on'); set(ax3,'XScale','log','YLim',[0 1.05]);
    semilogx(ax3, frf.f, frf.coh2, '.-','Color',[0.30 0.30 0.30],'MarkerSize',8,'LineWidth',0.4);
    yline(ax3, 0.5, '--', 'LineWidth',1.0);
    if ~isempty(dwell_pts)
        plot(ax3, [dwell_pts.f], [dwell_pts.coh2], 'o', ...
             'Color','k','MarkerFaceColor','k','MarkerSize',7);
    end
    ylabel(ax3, '\gamma^2'); xlabel(ax3,'frequency (Hz)');
    title(ax3,'Coherence^2 (trust > 0.5)');

    % ---- Fit summary box (row 3, col 4) ----
    ax4 = nexttile;
    axis(ax4,'off');
    txt = build_fit_textbox(fit);
    text(ax4, 0.02, 0.95, txt, 'VerticalAlignment','top', ...
         'FontName','Consolas','FontSize',12);
    title(ax4,'Fitted parameters');

    linkaxes([ax1 ax2 ax3], 'x');
    xlim(ax1, [max(frf.f(2),0.05), frf.f(end)]);

    sysid.presentation_style(fig);
    if nargin >= 7 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function plot_advanced_fits(frf, lm_fit, advanced, fit_nlhw, fit_narx, amp_mm, ...
                            inRole, outRole, save_path, custom_title)
% Overlay multiple parametric fits on the Bode plot with a comparison table.
% Each curve is a different model structure fit to the same FRF.
    methods = fieldnames(advanced);
    nM = numel(methods) + 1;
    if ~isempty(fit_nlhw), nM = nM + 1; end
    cmap = lines(nM);

    fig = figure('Color','w','Position',[40 40 1280 800], ...
                 'Name','Step 5 — Advanced parametric fitting');
    tl = tiledlayout(fig, 3, 4, 'TileSpacing','compact','Padding','compact');
    if nargin >= 10 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf(['Step 5 — Advanced parametric fitting:  ' ...
            '%s → %s  ·  BLA at amp = %.1f mm'], inRole, outRole, amp_mm), ...
            'FontSize',14,'FontWeight','bold','Interpreter','none');
    end

    % --- Magnitude (full-width) ---
    ax1 = nexttile([1 3]); hold(ax1,'on');
    set(ax1,'XScale','log','YScale','log');
    plot(ax1, frf.f, frf.mag, '.-', 'Color',[0.20 0.40 0.70], ...
         'MarkerSize',8, 'LineWidth',0.4, 'DisplayName','Welch H_1 (data)');
    plot(ax1, frf.f, abs(lm_fit.H_pred), '--', 'Color',cmap(1,:), ...
         'LineWidth',1.8, 'DisplayName','LM 4th (Step 4)');
    for k = 1:numel(methods)
        nm = methods{k};
        plot(ax1, frf.f, abs(advanced.(nm).H_pred), '-', 'Color',cmap(k+1,:), ...
             'LineWidth',1.5, 'DisplayName', advanced.(nm).name);
    end
    ylabel(ax1,'|H|'); title(ax1,'Magnitude'); legend(ax1,'Location','best','FontSize',9);
    grid(ax1,'on');

    % --- Comparison table (right column, rows 1-2) ---
    ax_tab = nexttile([2 1]); axis(ax_tab,'off');
    headers = sprintf('%-22s %10s', 'Method', 'Cost');
    rows = {sprintf('BLA amplitude: %.1f mm', amp_mm), '', headers, ...
            repmat('-',1,35)};
    rows{end+1} = sprintf('%-22s %10.4g', 'LM 4th (Step 4)', lm_fit.resnorm);
    for k = 1:numel(methods)
        nm = methods{k};
        c = advanced.(nm).cost;
        if isfinite(c)
            rows{end+1} = sprintf('%-22s %10.4g', advanced.(nm).name, c); %#ok<AGROW>
        end
    end
    if ~isempty(fit_nlhw)
        rows{end+1} = ''; %#ok<AGROW>
        rows{end+1} = sprintf('%-22s %10s', 'NLHW', '— (time domain)'); %#ok<AGROW>
    end
    text(ax_tab, 0.0, 0.95, strjoin(rows, newline), ...
        'VerticalAlignment','top','FontName','Consolas','FontSize',10);

    % --- Phase (full-width) ---
    ax2 = nexttile([1 3]); hold(ax2,'on'); set(ax2,'XScale','log');
    plot(ax2, frf.f, rad2deg(frf.phase), '.-', 'Color',[0.20 0.40 0.70], ...
         'MarkerSize',8, 'LineWidth',0.4, 'DisplayName','Welch H_1 (data)');
    plot(ax2, frf.f, rad2deg(unwrap(angle(lm_fit.H_pred))), '--', 'Color',cmap(1,:), ...
         'LineWidth',1.8, 'DisplayName','LM 4th (Step 4)');
    for k = 1:numel(methods)
        nm = methods{k};
        plot(ax2, frf.f, rad2deg(unwrap(angle(advanced.(nm).H_pred))), '-', ...
             'Color',cmap(k+1,:), 'LineWidth',1.5, 'DisplayName', advanced.(nm).name);
    end
    ylabel(ax2,'phase (deg)'); title(ax2,'Phase'); grid(ax2,'on');

    % --- Physical interpretation legend (bottom row, full width) ---
    ax_phys = nexttile([1 4]); axis(ax_phys,'off');
    phys_lines = {'Physical interpretation of each model:'};
    phys_lines{end+1} = sprintf('  • LM 4th: empirical 4th-order linear fit (frequency-domain LM)');
    for k = 1:numel(methods)
        nm = methods{k};
        phys_lines{end+1} = sprintf('  • %s:  %s', ...
            advanced.(nm).name, advanced.(nm).physical); %#ok<AGROW>
    end
    if ~isempty(fit_nlhw)
        phys_lines{end+1} = '  • NLHW (time domain — no Bode shown): Hammerstein-Wiener: static input nonlinearity + LTI + static output nonlinearity'; %#ok<AGROW>
    end
    if ~isempty(fit_narx)
        phys_lines{end+1} = '  • NARX (time domain — no Bode shown): nonlinear ARX, black-box, can fit ANY input-output map but loses physical meaning'; %#ok<AGROW>
    end
    text(ax_phys, 0.0, 0.95, strjoin(phys_lines, newline), ...
        'VerticalAlignment','top','FontSize',10);

    linkaxes([ax1 ax2], 'x');
    xlim(ax1, [max(frf.f(2),0.05), frf.f(end)]);

    sysid.presentation_style(fig);
    if nargin >= 9 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function plot_validate_multi(t, y_meas, preds, outRole, save_path, custom_title)
% Validation across multiple fits — overlay all predictions vs measured.
    fnames = fieldnames(preds);
    cmap = lines(numel(fnames) + 1);

    fig = figure('Color','w','Position',[40 40 1280 720], ...
                 'Name','Step 6 — Validation (all fits)');
    tl = tiledlayout(fig, 3, 1, 'TileSpacing','compact','Padding','compact');
    if nargin >= 6 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf('Step 6 — Validation on held-out half (%s)', outRole), ...
            'FontSize',14,'FontWeight','bold','Interpreter','none');
    end

    % Compute y-axis clamp from measured signal (so unstable predictions don't dominate)
    yrng = max(abs(y_meas)) * 3;

    % --- Top: time-domain comparison ---
    ax1 = nexttile([1 1]); hold(ax1,'on');
    plot(ax1, t, y_meas, '.', 'Color',[0.20 0.20 0.20], 'MarkerSize',5, ...
         'DisplayName','measured');
    for k = 1:numel(fnames)
        p = preds.(fnames{k});
        plot(ax1, t, p.y, '-', 'Color',cmap(k+1,:), 'LineWidth',1.3, ...
             'DisplayName',sprintf('%s (VAF=%+.1f%%)', p.name, p.vaf));
    end
    ylabel(ax1, label_for(outRole), 'Interpreter','none');
    legend(ax1, 'Location','best','FontSize',9);
    title(ax1, 'Validation: measured vs predicted');
    ylim(ax1, [-yrng, yrng]);

    % --- Middle: residuals ---
    ax2 = nexttile([1 1]); hold(ax2,'on');
    for k = 1:numel(fnames)
        p = preds.(fnames{k});
        plot(ax2, t, y_meas - p.y, '-', 'Color',cmap(k+1,:), 'LineWidth',1.0, ...
             'DisplayName', sprintf('%s (rms=%.3g)', p.name, rms(y_meas - p.y)));
    end
    yline(ax2, 0, ':');
    ylabel(ax2,'residual'); xlabel(ax2,'time (s)');
    legend(ax2,'Location','best','FontSize',9);
    title(ax2,'Residuals (smaller / more white-noise-like = better)');
    ylim(ax2, [-yrng, yrng]);

    % --- Bottom: bar chart of VAFs ---
    ax3 = nexttile;
    vafs = arrayfun(@(k) preds.(fnames{k}).vaf, 1:numel(fnames));
    names = arrayfun(@(k) preds.(fnames{k}).name, 1:numel(fnames), 'uni', 0);
    barColors = cmap(2:numel(fnames)+1, :);
    b = bar(ax3, vafs);
    b.FaceColor = 'flat';
    for k = 1:numel(fnames)
        b.CData(k,:) = barColors(k,:);
    end
    set(ax3,'XTick',1:numel(fnames),'XTickLabel',names, ...
        'XTickLabelRotation',20);
    ylabel(ax3,'VAF (%)'); title(ax3,'Validation VAF by method');
    grid(ax3,'on');
    yline(ax3, 0, '-', 'Color',[0.5 0.5 0.5]);

    linkaxes([ax1 ax2], 'x');
    sysid.presentation_style(fig);
    if nargin >= 5 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function plot_validate(t, y_meas, y_pred, vaf, aic, outRole, save_path, custom_title)
% (Kept for backward compatibility — Step 6 now uses plot_validate_multi.)
% Two stacked panels: prediction vs measurement, and residual.
    fig = figure('Color','w','Position',[80 80 1100 600], ...
                 'Name','Step 4 — Validation');
    tl = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
    if nargin >= 8 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf('Step 5 — Validation on held-out data:   VAF = %.2f%%   AIC = %.1f', ...
            vaf, aic), 'FontSize',14, 'FontWeight','bold');
    end

    ax1 = nexttile; hold(ax1,'on');
    plot(ax1, t, y_meas, '.', 'Color',[0.20 0.20 0.20], ...
         'MarkerSize',5, 'DisplayName','measured');
    plot(ax1, t, y_pred, '--', 'Color',[0.85 0.10 0.10], ...
         'LineWidth',1.6, 'DisplayName','model prediction');
    ylabel(ax1, label_for(outRole), 'Interpreter','none');
    legend(ax1, 'Location','best');
    title(ax1, sprintf('%s: measured vs predicted', outRole), 'Interpreter','none');

    ax2 = nexttile;
    res = y_meas - y_pred;
    plot(ax2, t, res, '.', 'Color',[0.30 0.45 0.70], 'MarkerSize',4);
    ylabel(ax2, 'residual'); xlabel(ax2, 'time (s)');
    title(ax2, sprintf('Residual (rms = %.3g)', rms(res)));

    linkaxes([ax1 ax2], 'x');
    sysid.presentation_style(fig);
    if nargin >= 7 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

% ============================================================================
%                        SMALL HELPERS
% ============================================================================

function plot_nlhw(frf, fit_lin, sys, vaf_lin, vaf_nlhw, ...
                   t_va, y_va, y_pred_lin, y_pred_nlhw, ...
                   u_tr, inRole, outRole, save_path, custom_title)
% Bode-style comparison of the linear LM fit vs the NLHW linear block.
% Three rows like Step 4: magnitude, phase, coherence² — with the
% NLHW linear-block frequency response added as a third curve. Side
% panel shows the input static nonlinearity f(u). Bottom shows a
% short validation strip with VAF numbers.

    fig = figure('Color','w','Position',[40 40 1280 800], ...
                 'Name','Step 6 — Nonlinear (Hammerstein-Wiener) fit');
    tl = tiledlayout(fig, 4, 4, 'TileSpacing','compact','Padding','compact');
    if nargin >= 14 && ~isempty(custom_title)
        title(tl, custom_title, 'FontSize',14, 'FontWeight','bold','Interpreter','none');
    else
        title(tl, sprintf(['Step 6 — NLHW fit:  %s → %s    ' ...
            'Linear VAF=%.1f%%    NLHW VAF=%.1f%%'], ...
            inRole, outRole, vaf_lin, vaf_nlhw), ...
            'FontSize',14, 'FontWeight','bold','Interpreter','none');
    end

    % --- Compute NLHW linear-block frequency response on frf.f grid ---
    H_nl = []; mag_nl = []; phase_nl_deg = [];
    try
        % Discrete-time linear block from idnlhw: B(z)/F(z), Ts = sys.Ts
        H_nl = freqz(sys.B, sys.F, frf.f, 1/sys.Ts);
        mag_nl = abs(H_nl);
        phase_nl_deg = rad2deg(unwrap(angle(H_nl)));
    catch
        % Fallback: leave empty — won't plot the NLHW curve
    end

    % --- Bode magnitude (rows 1, cols 1-3) ---
    ax1 = nexttile([1 3]); hold(ax1,'on');
    set(ax1,'XScale','log','YScale','log');
    loglog(ax1, frf.f, frf.mag, '.-', 'Color',[0.20 0.40 0.70], ...
           'MarkerSize',8, 'LineWidth',0.4, 'DisplayName','Welch H_1 (data)');
    loglog(ax1, frf.f, abs(fit_lin.H_pred), '--', 'Color',[0.85 0.10 0.10], ...
           'LineWidth',2.0, 'DisplayName','linear LM fit');
    if ~isempty(H_nl)
        loglog(ax1, frf.f, mag_nl, '-', 'Color',[0.10 0.55 0.30], ...
               'LineWidth',1.8, 'DisplayName','NLHW linear block');
    end
    ylabel(ax1,'|H|');
    title(ax1, 'Magnitude');
    legend(ax1,'Location','best');

    % --- Right column: input static nonlinearity (rows 1-2, col 4) ---
    ax_nl = nexttile([2 1]); hold(ax_nl,'on');
    try
        u_range = linspace(min(u_tr), max(u_tr), 200)';
        f_u = evaluate(sys.InputNonlinearity, u_range);
        plot(ax_nl, u_range, f_u, '-', 'Color',[0.20 0.40 0.70], 'LineWidth',1.8, ...
             'DisplayName','fitted f(u)');
        plot(ax_nl, u_range, u_range, ':', 'Color',[0.5 0.5 0.5], ...
             'DisplayName','identity');
        legend(ax_nl,'Location','best');
        % Detect the degenerate "f(u) = 0" failure
        if max(abs(f_u)) < 1e-3 * max(abs(u_range))
            text(ax_nl, 0.02, 0.95, '*** f(u) collapsed to zero — fit failed ***', ...
                 'Units','normalized','Color',[0.7 0 0],'FontWeight','bold');
        end
    catch ME
        text(ax_nl, 0.05, 0.5, ['(input NL plot failed: ' ME.message ')'], ...
             'Units','normalized','FontAngle','italic','Color',[0.5 0 0]);
    end
    xlabel(ax_nl,'u'); ylabel(ax_nl,'f(u)');
    title(ax_nl,'Input static nonlinearity');
    grid(ax_nl,'on');

    % --- Bode phase (row 2, cols 1-3) ---
    ax2 = nexttile([1 3]); hold(ax2,'on'); set(ax2,'XScale','log');
    semilogx(ax2, frf.f, rad2deg(frf.phase), '.-', 'Color',[0.20 0.40 0.70], ...
             'MarkerSize',8, 'LineWidth',0.4, 'DisplayName','Welch H_1 (data)');
    semilogx(ax2, frf.f, rad2deg(unwrap(angle(fit_lin.H_pred))), '--', ...
             'Color',[0.85 0.10 0.10], 'LineWidth',2.0, 'DisplayName','linear LM fit');
    if ~isempty(H_nl)
        semilogx(ax2, frf.f, phase_nl_deg, '-', 'Color',[0.10 0.55 0.30], ...
                 'LineWidth',1.8, 'DisplayName','NLHW linear block');
    end
    ylabel(ax2,'phase (deg)');
    title(ax2,'Phase');

    % --- Coherence² (row 3, cols 1-3) ---
    ax3 = nexttile([1 3]); hold(ax3,'on'); set(ax3,'XScale','log','YLim',[0 1.05]);
    semilogx(ax3, frf.f, frf.coh2, '.-','Color',[0.30 0.30 0.30], ...
             'MarkerSize',8,'LineWidth',0.4);
    yline(ax3, 0.5, '--', 'LineWidth',1.0);
    ylabel(ax3,'\gamma^2'); title(ax3,'Coherence^2');

    % --- Right col, row 3: Fit-quality summary ---
    ax_summary = nexttile; axis(ax_summary,'off');
    lines = {
        sprintf('Linear LM fit')
        sprintf('  validation VAF = %+.1f %%', vaf_lin)
        ''
        sprintf('NLHW model')
        sprintf('  validation VAF = %+.1f %%', vaf_nlhw)
        sprintf('  improvement   = %+.1f pts', vaf_nlhw - vaf_lin)
        ''
        sprintf('NLHW linear block')
        sprintf('  order  nb=%d  nf=%d', numel(sys.B)-1, numel(sys.F)-1)
        sprintf('  Ts = %.4f s', sys.Ts)
        };
    if ~isempty(H_nl)
        % Stability check
        try
            poles = roots(sys.F);
            max_pole = max(abs(poles));
            lines{end+1} = sprintf('  max |pole| = %.3f%s', max_pole, ...
                ternary(max_pole >= 1, '  *** UNSTABLE ***', ''));
        catch
        end
    end
    text(ax_summary, 0.02, 0.95, strjoin(lines, newline), ...
         'VerticalAlignment','top','FontName','Consolas','FontSize',11);

    % --- Bottom row (full width): time-domain validation ---
    ax_t = nexttile([1 4]); hold(ax_t,'on');
    plot(ax_t, t_va, y_va, '.', 'Color',[0.20 0.20 0.20], 'MarkerSize',4, ...
         'DisplayName','measured');
    plot(ax_t, t_va, y_pred_lin, '-', 'Color',[0.85 0.10 0.10], 'LineWidth',1.2, ...
         'DisplayName','linear pred');
    plot(ax_t, t_va, y_pred_nlhw, '-', 'Color',[0.10 0.55 0.30], 'LineWidth',1.2, ...
         'DisplayName','NLHW pred');
    ylabel(ax_t, label_for(outRole), 'Interpreter','none');
    xlabel(ax_t,'time (s)');
    legend(ax_t,'Location','best');
    title(ax_t, 'Validation (held-out half) — time-domain comparison');
    % Clamp y-axis if NLHW prediction blew up (so the rest stays visible)
    y_data_range = max(abs(y_va)) * 3;
    ylim(ax_t, [-y_data_range, y_data_range]);

    linkaxes([ax1 ax2 ax3], 'x');
    xlim(ax1, [max(frf.f(2),0.05), frf.f(end)]);

    sysid.presentation_style(fig);
    if nargin >= 13 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function v = ternary(cond, ifyes, ifno)
    if cond, v = ifyes; else, v = ifno; end
end

function thd_pct = compute_thd(u, y, fs)
% Estimate output total harmonic distortion as a fraction of the
% output energy at frequencies the input *also* has energy at.
% A linear system reproduces only the input's frequencies; energy at
% other frequencies = nonlinear distortion.
    N = numel(u); win = hann(N);
    U = abs(fft(u .* win)); Y = abs(fft(y .* win));
    f = (0:floor(N/2))' * fs/N;
    U = U(1:numel(f)); Y = Y(1:numel(f));

    % Mask of "input-active" bins (top 1% of input PSD)
    thr   = max(U) * 0.05;
    inMask = U > thr;
    if sum(inMask) < 2
        thd_pct = NaN; return;
    end

    % Use Y power inside vs outside the input-active mask
    P_in  = sum(Y(inMask).^2);
    P_out = sum(Y(~inMask).^2);
    thd_pct = 100 * P_out / max(P_in + P_out, eps);
end

function plot_set_summary(swp, inRole, outRole, save_path)
% Compare BLAs across conditions:  overlaid Bodes (mag/phase/coh^2) plus
% a parameter-vs-amplitude panel.

    n = numel(swp);
    cmap = parula(max(n,2));

    fig = figure('Color','w','Position',[40 40 1280 820], ...
                 'Name','Nonlinearity sweep — comparison');
    tl = tiledlayout(fig, 4, 4, 'TileSpacing','compact','Padding','compact');
    title(tl, sprintf('Nonlinearity sweep:   %s → %s   (%d conditions)', ...
        inRole, outRole, n), 'FontSize',14,'FontWeight','bold','Interpreter','none');

    % --- Bode magnitude (rows 1, cols 1-3) ---
    ax1 = nexttile([1 3]); hold(ax1,'on');
    set(ax1,'XScale','log','YScale','log');
    for k = 1:n
        s = swp(k);
        plot(ax1, s.frf.f, s.frf.mag, '.-', 'Color', cmap(k,:), ...
             'MarkerSize', 8, 'LineWidth',0.4, 'DisplayName', s.label);
        plot(ax1, s.frf.f, abs(s.fit.H_pred), '-', 'Color', cmap(k,:), ...
             'LineWidth', 1.4, 'HandleVisibility','off');
    end
    ylabel(ax1,'|H|'); title(ax1,'Magnitude (dots = Welch, line = LM fit)');
    legend(ax1,'Location','best');

    % --- Parameter vs amplitude (col 4, rows 1-2) ---
    ax_p = nexttile([2 1]); hold(ax_p,'on');
    yyaxis(ax_p,'left');
    plot(ax_p, [swp.amp_mm], arrayfun(@(s) s.fit.params(2)/(2*pi), swp), 'o-', ...
         'LineWidth',1.6, 'MarkerSize',8, 'MarkerFaceColor','auto');
    ylabel(ax_p,'f_n  (Hz)');
    yyaxis(ax_p,'right');
    if all(arrayfun(@(s) numel(s.fit.params) >= 3, swp))
        plot(ax_p, [swp.amp_mm], arrayfun(@(s) s.fit.params(3), swp), 's--', ...
             'LineWidth',1.6, 'MarkerSize',8);
        ylabel(ax_p,'\zeta');
    end
    xlabel(ax_p,'amplitude (mm)');
    title(ax_p,'Parameter drift');
    grid(ax_p,'on');

    % --- Bode phase (row 2, cols 1-3) ---
    ax2 = nexttile([1 3]); hold(ax2,'on'); set(ax2,'XScale','log');
    for k = 1:n
        s = swp(k);
        plot(ax2, s.frf.f, rad2deg(s.frf.phase), '.-', 'Color', cmap(k,:), ...
             'MarkerSize', 8, 'LineWidth',0.4);
        plot(ax2, s.frf.f, rad2deg(unwrap(angle(s.fit.H_pred))), '-', ...
             'Color', cmap(k,:), 'LineWidth', 1.4);
    end
    ylabel(ax2,'phase (deg)'); title(ax2,'Phase');

    % --- Coherence² (row 3, cols 1-3) ---
    ax3 = nexttile([1 3]); hold(ax3,'on'); set(ax3,'XScale','log','YLim',[0 1.05]);
    for k = 1:n
        plot(ax3, swp(k).frf.f, swp(k).frf.coh2, '.-', 'Color', cmap(k,:), ...
             'MarkerSize', 8, 'LineWidth',0.4);
    end
    yline(ax3, 0.5, '--');
    ylabel(ax3,'\gamma^2'); xlabel(ax3,'frequency (Hz)');
    title(ax3,'Coherence^2');

    % --- THD vs amplitude (col 4, row 3) ---
    ax_t = nexttile; hold(ax_t,'on');
    plot(ax_t, [swp.amp_mm], [swp.thd_pct], 'o-', ...
         'LineWidth',1.6,'MarkerSize',8,'MarkerFaceColor','auto', ...
         'Color',[0.85 0.20 0.20]);
    xlabel(ax_t,'amplitude (mm)'); ylabel(ax_t,'THD (%)');
    title(ax_t,'Distortion'); grid(ax_t,'on');

    % --- Summary table (row 4, all cols) ---
    ax_tab = nexttile([1 4]); axis(ax_tab,'off');
    headers = sprintf('%-12s %8s %8s %8s %8s %8s %8s', ...
        'label','amp(mm)','K','f_n(Hz)','zeta','VAF(%)','THD(%)');
    rows = {headers, repmat('-',1,80)};
    for k = 1:n
        s = swp(k); p = s.fit.params;
        K = p(1); fn = p(2)/(2*pi); zeta = NaN;
        if numel(p) >= 3, zeta = p(3); end
        rows{end+1} = sprintf('%-12s %8.2f %8.3g %8.3f %8.3f %8.1f %8.1f', ...
            s.label, s.amp_mm, K, fn, zeta, s.vaf, s.thd_pct); %#ok<AGROW>
    end
    text(ax_tab, 0.0, 0.95, strjoin(rows, newline), ...
         'VerticalAlignment','top','FontName','Consolas','FontSize',11);

    sysid.presentation_style(fig);
    if nargin >= 4 && ~isempty(save_path)
        exportgraphics(fig, save_path, 'Resolution', 200);
    end
end

function role = guess_role(name)
    n = lower(name);
    is_theory = contains(n,'theor') || contains(n,'ideal') || ...
                contains(n,'commanded') || contains(n,'computed');
    if     contains(n,'time'),                       role = 'time';
    elseif contains(n,'pist') && contains(n,'vel'),  role = 'piston_vel';
    elseif contains(n,'vel') && ~contains(n,'water'),role = 'piston_vel';
    elseif contains(n,'pist') || contains(n,'pos'),  role = 'piston_pos';
    elseif contains(n,'air') && contains(n,'pres'),  role = 'inlet_air_p';
    elseif contains(n,'air') && (contains(n,'flow')||contains(n,'q'))
        if is_theory, role = 'inlet_air_q_theory';
        else,         role = 'inlet_air_q';
        end
    elseif (contains(n,'water')||contains(n,'out')) && contains(n,'pres'), role = 'outlet_water_p';
    elseif (contains(n,'water')||contains(n,'out')) && (contains(n,'flow')||contains(n,'q')), role = 'outlet_water_q';
    else,  role = '(ignore)';
    end
end

function s = label_for(role)
    map = struct( ...
        'piston_pos',          'piston pos (mm)', ...
        'piston_vel',          'piston vel (mm/s)', ...
        'inlet_air_p',         'inlet air P (kPa)', ...
        'inlet_air_q',         'inlet air Q measured (LPM)', ...
        'inlet_air_q_theory',  'inlet air Q theoretical (LPM)', ...
        'outlet_water_p',      'outlet water P (kPa)', ...
        'outlet_water_q',      'outlet water Q (LPM)');
    if isfield(map, role), s = map.(role); else, s = role; end
end

function s = fit_summary(fit)
    parts = arrayfun(@(k) sprintf('%s=%.3g', fit.param_names{k}, fit.params(k)), ...
                     1:numel(fit.params), 'uni', 0);
    s = ['fit:  ' strjoin(parts, '   ')];
end

function txt = build_fit_textbox(fit)
    lines = {};
    for k = 1:numel(fit.params)
        lines{end+1} = sprintf('%-6s = %10.4g', fit.param_names{k}, fit.params(k)); %#ok<AGROW>
    end
    if fit.order == 2
        K = fit.params(1); wn = fit.params(2); zeta = fit.params(3);
        lines{end+1} = '';
        lines{end+1} = sprintf('f_n   = %10.4g  Hz', wn/(2*pi));
        lines{end+1} = sprintf('K     = %10.4g  (DC gain)', K);
        lines{end+1} = sprintf('zeta  = %10.4g', zeta);
    end
    lines{end+1} = '';
    lines{end+1} = sprintf('SSE   = %10.4g', fit.resnorm);
    flag_msg = lm_exitflag_msg(fit.exitflag);
    lines{end+1} = sprintf('LM    : %s', flag_msg);
    txt = strjoin(lines, newline);
end

function s = lm_exitflag_msg(flag)
    switch flag
        case  1, s = 'converged (gradient)';
        case  2, s = 'converged (step size)';
        case  3, s = 'converged (residual)';
        case  4, s = 'magnitude of search direction < tol';
        case  0, s = '*** hit max iterations (NOT converged)';
        case -1, s = '*** stopped by user';
        case -2, s = '*** problem infeasible';
        otherwise, s = sprintf('exit flag %d', flag);
    end
end
