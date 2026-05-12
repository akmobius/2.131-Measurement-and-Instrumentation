function pump_waveform_calc()
% PUMP_WAVEFORM_CALC  Convert iSV57T controller parameters to physical
% units, simulate the resulting trapezoidal waveform, and show its
% time-domain shape, frequency content, and limits.
%
% Inputs (matches the iSV servo controller GUI):
%   target RPM             — plateau velocity (rev/min)
%   stroke (0.1 rev units) — total back-and-forth stroke; 1 unit = 0.5 mm
%   cycles                 — number of full back-and-forth cycles
%   accel time (ms/Krpm)   — time to ramp from 0 → 1000 RPM
%   decel time (ms/Krpm)   — time to ramp from 1000 RPM → 0
%
% Mechanical conversion:
%   1 rev = 5 mm linear         (SFU1605 ballscrew)
%   bore = 80 mm  →  area = π·40² = 5026.55 mm²
%   so 1 mm of motion = 5.0265 mL air

    % --- Constants ---
    MM_PER_REV     = 5;
    AREA_MM2       = pi*40^2;            % 5026.55 mm²
    ML_PER_MM      = AREA_MM2/1000;      % 5.0265 mL/mm
    MAX_VEL_MM_S   = 208;                % firmware cap
    MAX_STROKE_MM  = 90;                 % one-sided travel ceiling (home -> peak)

    % --- Figure layout ---
    fig = uifigure('Name','Pump Waveform Calculator', 'Position',[160 50 1180 800]);
    g = uigridlayout(fig, [2 2]);
    g.ColumnWidth = {320, '1x'};
    g.RowHeight   = {220, '1x'};

    % --- Reverse calc (top-left) ---
    rcPanel = uipanel(g, 'Title','Target waveform  (reverse calc)', ...
        'FontWeight','bold');
    rcPanel.Layout.Row = 1; rcPanel.Layout.Column = 1;
    RC = uigridlayout(rcPanel, [5 2]);
    RC.RowHeight   = {30, 30, 30, 30, 30};
    RC.ColumnWidth = {150, '1x'};

    uilabel(RC,'Text','Target f\x2080 (Hz):','HorizontalAlignment','right');
    f0Fld = uieditfield(RC,'numeric','Value',0.5,'Limits',[0.01 50]);

    uilabel(RC,'Text','Target stroke (mm):','HorizontalAlignment','right');
    strokeMmFld = uieditfield(RC,'numeric','Value',80,'Limits',[1 90]);

    uilabel(RC,'Text','Accel fraction:','HorizontalAlignment','right');
    afracFld = uieditfield(RC,'numeric','Value',0.10,'Limits',[0.01 0.49]);
    uilabel(RC,'Text', ...
        '(fraction of half-cycle spent ramping up — 0.1 = ~80% plateau)', ...
        'FontAngle','italic','FontSize',10);

    uibutton(RC,'Text','Compute  →  fill controller fields below', ...
        'BackgroundColor',[0.85 0.95 0.85], 'ButtonPushedFcn',@onReverseCalc);

    rcStatus = uilabel(RC,'Text','','FontAngle','italic');
    rcStatus.Layout.Row = 5; rcStatus.Layout.Column = [1 2];

    % --- Controller inputs (bottom-left) ---
    leftPanel = uipanel(g, 'Title','Controller inputs','FontWeight','bold');
    leftPanel.Layout.Row = 2; leftPanel.Layout.Column = 1;
    L = uigridlayout(leftPanel, [8 2]);
    L.RowHeight   = {30, 30, 30, 30, 30, 12, '1x', 36};
    L.ColumnWidth = {150, '1x'};

    uilabel(L,'Text','Target RPM:','HorizontalAlignment','right');
    rpmFld = uieditfield(L,'numeric','Value',300,'Limits',[1 3000]);
    rpmFld.ValueChangedFcn = @(~,~) update();

    uilabel(L,'Text','Stroke (0.1 rev units):','HorizontalAlignment','right');
    strokeFld = uieditfield(L,'numeric','Value',160,'Limits',[1 1000]); % 160 = 80 mm
    strokeFld.ValueChangedFcn = @(~,~) update();

    uilabel(L,'Text','Cycles:','HorizontalAlignment','right');
    cycFld = uieditfield(L,'numeric','Value',10,'Limits',[1 1000], ...
                         'RoundFractionalValues','on');
    cycFld.ValueChangedFcn = @(~,~) update();

    uilabel(L,'Text','Accel/decel (ms/Krpm):','HorizontalAlignment','right');
    accFld = uieditfield(L,'numeric','Value',100,'Limits',[1 5000]);
    accFld.ValueChangedFcn = @(~,~) update();

    uilabel(L,'Text','(controller always matches accel = decel)', ...
        'FontAngle','italic','FontSize',10);

    uilabel(L,'Text','');                                                 % row 6 spacer
    uilabel(L,'Text','');

    derivedTxt = uilabel(L, 'Text','', 'VerticalAlignment','top', ...
        'FontName','Consolas','FontSize',12, 'WordWrap','on', ...
        'BackgroundColor',[0.97 0.97 0.97]);
    derivedTxt.Layout.Row = 7;
    derivedTxt.Layout.Column = [1 2];

    exportBtn = uibutton(L, 'Text','Export waveform CSV...', ...
        'BackgroundColor',[0.85 0.92 1.00], 'ButtonPushedFcn',@onExport);
    exportBtn.Layout.Row = 8;
    exportBtn.Layout.Column = [1 2];

    % --- waveform cache for export (filled at the end of update()) ---
    cache = struct('t',[], 'pos',[], 'vel',[], 'flow_lpm',[], ...
                   'fs',[], 'f0',[], 'meta',struct());

    % --- Right column: plots (spans both rows) ---
    rightPanel = uipanel(g, 'Title','Predicted waveform', 'FontWeight','bold');
    rightPanel.Layout.Row = [1 2]; rightPanel.Layout.Column = 2;
    R = uigridlayout(rightPanel, [3 1]);
    R.RowHeight = {'1x','1x','1x'};
    axPos = uiaxes(R);
    axVel = uiaxes(R);
    axFFT = uiaxes(R);

    update();

    % ============================ reverse calc ============================
    function onReverseCalc(~,~)
        try
            f0      = f0Fld.Value;
            stroke  = strokeMmFld.Value;
            afrac   = afracFld.Value;

            T_half  = 1/(2*f0);
            t_acc   = afrac * T_half;
            t_plat  = (1 - 2*afrac) * T_half;

            % stroke = a*t_acc^2 + a*t_acc*t_plat = a*t_acc*(t_acc + t_plat)
            a_req = stroke / (t_acc * (t_acc + t_plat));
            v_req = a_req * t_acc;

            % Convert physics → controller units
            rpm_req   = v_req * 60 / MM_PER_REV;
            units_req = round(stroke / (0.1 * MM_PER_REV));
            accMs_req = (MM_PER_REV/60) * 1e6 / a_req;

            % Clamp to each field's allowed range, then push
            rpmLim = rpmFld.Limits;    rpm_clamped   = clamp(rpm_req,   rpmLim);
            sLim   = strokeFld.Limits; units_clamped = clamp(units_req, sLim);
            aLim   = accFld.Limits;    accMs_clamped = clamp(accMs_req, aLim);

            rpmFld.Value    = rpm_clamped;
            strokeFld.Value = units_clamped;
            accFld.Value    = accMs_clamped;

            warns = {};
            if v_req > MAX_VEL_MM_S
                warns{end+1} = sprintf('peak v=%.0f > %.0f mm/s — motor cap', v_req, MAX_VEL_MM_S);
            end
            if stroke > 90
                warns{end+1} = sprintf('stroke %.0f > 90 mm travel limit', stroke);
            end
            if abs(rpm_clamped - rpm_req) > 1e-6 || abs(accMs_clamped - accMs_req) > 1e-6
                warns{end+1} = 'values clamped to controller field range';
            end

            if isempty(warns)
                rcStatus.Text = sprintf(['→ RPM %.0f, %d units, %.1f ms/Krpm   ' ...
                    '(v=%.1f mm/s, a=%.0f mm/s\xb2)'], ...
                    rpm_req, units_req, accMs_req, v_req, a_req);
                rcStatus.FontColor = [0 0.4 0];
            else
                rcStatus.Text = ['*** ' strjoin(warns, ' ; ')];
                rcStatus.FontColor = [0.7 0 0];
            end

            drawnow;     % flush programmatic field-value changes
            update();    % refresh plots
            drawnow;
        catch ME
            rcStatus.Text = ['ERROR: ' ME.message];
            rcStatus.FontColor = [0.7 0 0];
        end
    end

    function v = clamp(x, lim)
        v = max(lim(1), min(x, lim(2)));
    end

    % ============================ logic ============================

    function update()
        rpm    = rpmFld.Value;
        nUnits = strokeFld.Value;
        nCyc   = cycFld.Value;
        accMs  = accFld.Value;
        decMs  = accMs;             % controller always matches accel = decel

        % --- Convert to SI units ---
        stroke_mm = nUnits * 0.1 * MM_PER_REV;       % total peak-to-peak
        amp_mm    = stroke_mm/2;                     % from center
        v_mm_s    = rpm * MM_PER_REV / 60;
        a_mm_s2   = (MM_PER_REV/60) * 1e6 / accMs;   % see notes below
        d_mm_s2   = (MM_PER_REV/60) * 1e6 / decMs;

        peak_flow_LPM = v_mm_s * ML_PER_MM * 60 / 1000;
        vol_per_cycle_mL = stroke_mm * ML_PER_MM;

        % --- Build one full back-and-forth cycle: -amp -> +amp -> -amp ---
        [t_cyc, p_cyc, v_peak_actual] = build_cycle(amp_mm, v_mm_s, ...
                                                    a_mm_s2, d_mm_s2);
        T_cyc = t_cyc(end);

        % Stitch nCyc cycles, dropping the duplicate sample at each join
        t = t_cyc; p = p_cyc;
        for k = 2:nCyc
            t = [t; t_cyc(2:end) + (k-1)*T_cyc]; %#ok<AGROW>
            p = [p; p_cyc(2:end)];               %#ok<AGROW>
        end
        % Resample to uniform 1 kHz for plotting + FFT
        fs = 1000;
        t_uni = (0:1/fs:t(end))';
        p_uni = interp1(t, p, t_uni, 'linear');
        v_uni = gradient(p_uni) * fs;

        f0 = 1/T_cyc;

        % --- Limit checks ---
        ok_vel    = v_mm_s    <= MAX_VEL_MM_S;
        ok_stroke = stroke_mm <= MAX_STROKE_MM;
        ok_acc    = a_mm_s2   < 1e5;   % sanity

        % --- Update derived readout ---
        warn = '';
        if ~ok_vel,    warn = [warn sprintf('  *** v=%.1f mm/s > %.0f cap\n', v_mm_s, MAX_VEL_MM_S)]; end
        if ~ok_stroke, warn = [warn sprintf('  *** stroke=%.1f mm > %.0f mm max travel\n', stroke_mm, MAX_STROKE_MM)]; end
        triangle_collapse = (v_mm_s^2 / (2*a_mm_s2)) >= amp_mm;

        lines = {
            sprintf('Stroke:           %7.2f mm  (0 -> peak -> 0)', stroke_mm)
            sprintf('AC amplitude:     %7.2f mm  (\xbd peak-to-peak)', amp_mm)
            sprintf('Mean position:    %7.2f mm  (offset from home)', amp_mm)
            sprintf('Volume per cycle: %7.2f mL', vol_per_cycle_mL)
            sprintf('Plateau velocity: %7.2f mm/s', v_mm_s)
            sprintf('Peak air flow:    %7.2f L/min', peak_flow_LPM)
            sprintf('Accel = decel:    %7.0f mm/s\xb2', a_mm_s2)
            ''
            sprintf('Cycle period:     %7.3f s', T_cyc)
            sprintf('Fundamental f\x2080: %7.3f Hz', f0)
            sprintf('Total record:     %7.1f s  (%d cycles)', t(end), nCyc)
            ''
            sprintf('Harmonic comb:    f\x2080, 3f\x2080, 5f\x2080 ... = %.2f, %.2f, %.2f, %.2f Hz', ...
                f0, 3*f0, 5*f0, 7*f0)
        };
        if triangle_collapse
            lines{end+1} = '';
            lines{end+1} = '  Note: triangle collapse — no plateau.';
            lines{end+1} = sprintf('  Actual peak v = %.1f mm/s', sqrt(a_mm_s2*amp_mm));
        end
        if ~isempty(warn)
            lines{end+1} = '';
            lines{end+1} = warn;
        end
        derivedTxt.Text = strjoin(lines, newline);

        % --- Plots ---
        cla(axPos);
        plot(axPos, t_uni, p_uni, '.', 'Color',[0.10 0.45 0.80], 'MarkerSize',3);
        ylabel(axPos, 'position (mm)'); grid(axPos,'on');
        title(axPos, sprintf('Position waveform   (f_0 = %.3f Hz, total %.1f s)', f0, t(end)));
        yline(axPos, 0,              '--', 'Color',[0.5 0.5 0.5]);   % home
        yline(axPos, MAX_STROKE_MM,  '--', 'Color','r');             % travel ceiling
        ylim(axPos, [-5, max(MAX_STROKE_MM, stroke_mm) + 5]);

        cla(axVel);
        plot(axVel, t_uni, v_uni, '.', 'Color',[0.20 0.55 0.30], 'MarkerSize',3);
        ylabel(axVel, 'velocity (mm/s)'); grid(axVel,'on');
        title(axVel, sprintf('Velocity   (peak %.1f mm/s; flow ≈ %.1f L/min)', ...
              max(abs(v_uni)), max(abs(v_uni))*ML_PER_MM*60/1000));
        yline(axVel,  MAX_VEL_MM_S, '--', 'Color','r');
        yline(axVel, -MAX_VEL_MM_S, '--', 'Color','r');

        % FFT (single-sided amplitude spectrum)
        N = numel(p_uni); win = hann(N);
        P = fft(p_uni .* win);
        f = (0:floor(N/2))' * fs/N;
        A = abs(P(1:numel(f))) * 2/sum(win);
        cla(axFFT);
        plot(axFFT, f, A, '.', 'Color',[0.85 0.33 0.10], 'MarkerSize',5);
        set(axFFT,'XScale','log','YScale','log');
        xlim(axFFT, [max(f0/4, 0.02), 50]);
        xlabel(axFFT, 'frequency (Hz)'); ylabel(axFFT, '|U(f)|');
        grid(axFFT,'on');
        title(axFFT, 'Position spectrum  (harmonic comb of the trapezoid)');
        for k = 1:2:9
            xline(axFFT, k*f0, ':', 'Color',[0.4 0.4 0.4]);
        end

        % --- Cache for CSV export ---
        cache.t        = t_uni;
        cache.pos      = p_uni;
        cache.vel      = v_uni;
        cache.flow_lpm = v_uni * ML_PER_MM * 60 / 1000;   % piston-displacement flow
        cache.fs       = fs;
        cache.f0       = f0;
        cache.meta     = struct( ...
            'rpm',rpm,'stroke_mm',stroke_mm,'amp_mm',amp_mm, ...
            'peak_velocity_mm_s',v_mm_s, ...
            'peak_flow_LPM',peak_flow_LPM, ...
            'accel_mm_s2',a_mm_s2, ...
            'cycles',nCyc,'fundamental_Hz',f0,'duration_s',t(end));
    end

    % ============================ export ============================
    function onExport(~,~)
        if isempty(cache.t)
            uialert(fig, 'No waveform yet — change a field to populate first.', ...
                    'Nothing to export'); return;
        end
        default_name = sprintf('waveform_f0=%.2fHz_amp=%.0fmm.csv', ...
                               cache.f0, cache.meta.amp_mm);
        [fn, fp] = uiputfile({'*.csv','CSV files'}, ...
                             'Save waveform as...', default_name);
        if isequal(fn, 0), return; end
        fullpath = fullfile(fp, fn);

        T = table(cache.t, cache.pos, cache.vel, cache.flow_lpm, ...
            'VariableNames', ...
            {'time_s','piston_pos_mm','piston_vel_mm_s', ...
             'inlet_air_flow_theory_LPM'});
        writetable(T, fullpath);

        % Sidecar metadata file alongside the CSV, for slide notes / record
        m = cache.meta;
        meta_lines = {
            sprintf('csv: %s', fn)
            sprintf('fundamental_Hz: %.4f', m.fundamental_Hz)
            sprintf('stroke_mm: %.2f', m.stroke_mm)
            sprintf('amp_mm: %.2f', m.amp_mm)
            sprintf('rpm: %.1f', m.rpm)
            sprintf('peak_velocity_mm_s: %.2f', m.peak_velocity_mm_s)
            sprintf('peak_flow_LPM: %.2f', m.peak_flow_LPM)
            sprintf('accel_mm_s2: %.0f', m.accel_mm_s2)
            sprintf('cycles: %d', m.cycles)
            sprintf('duration_s: %.3f', m.duration_s)
            sprintf('fs: %.1f', cache.fs)
        };
        meta_path = fullfile(fp, [fn(1:end-4) '_meta.txt']);
        fid = fopen(meta_path, 'w');
        if fid > 0
            fprintf(fid, '%s\n', meta_lines{:});
            fclose(fid);
        end

        rcStatus.Text = sprintf('Exported %d rows  →  %s  (+ _meta.txt)', ...
                                height(T), fn);
        rcStatus.FontColor = [0 0.4 0];
    end
end

% =============================================================================
function [t, p, v_peak] = build_cycle(amp, v, a, d)
% Build ONE full back-and-forth cycle going  -amp -> +amp -> -amp  using a
% trapezoidal velocity profile (accel a, plateau v, decel d).
% Returns time + centered position at 1 ms resolution and the actual peak
% velocity reached (which differs from v if the trapezoid collapses to a
% triangle).

    dt = 1e-3;
    half_dist = 2*amp;           % one-direction stroke length

    % Sizing the trapezoid for the half-stroke
    t_acc = v/a;
    t_dec = v/d;
    d_acc = 0.5*a*t_acc^2;
    d_dec = 0.5*d*t_dec^2;
    if d_acc + d_dec >= half_dist
        % Triangle collapse
        v_peak = sqrt(2*half_dist / (1/a + 1/d));
        t_acc  = v_peak/a;
        t_dec  = v_peak/d;
        t_plat = 0;
    else
        v_peak = v;
        t_plat = (half_dist - d_acc - d_dec) / v;
    end
    T_half = t_acc + t_plat + t_dec;

    % Build velocity profile for the FULL cycle (forward then return)
    T_full = 2 * T_half;
    t = (0:dt:T_full)';
    vel = zeros(size(t));
    for k = 1:numel(t)
        tk = t(k);
        if tk < t_acc
            vel(k) = a * tk;                                    % fwd accel
        elseif tk < t_acc + t_plat
            vel(k) = v_peak;                                    % fwd plateau
        elseif tk < T_half
            vel(k) = v_peak - d * (tk - t_acc - t_plat);        % fwd decel
        elseif tk < T_half + t_acc
            vel(k) = -a * (tk - T_half);                        % rev accel
        elseif tk < T_half + t_acc + t_plat
            vel(k) = -v_peak;                                   % rev plateau
        else
            vel(k) = -v_peak + d * (tk - T_half - t_acc - t_plat); % rev decel
        end
    end

    % Integrate velocity. Cycle starts at home (0), peaks at full stroke
    % (2*amp = stroke), and returns to 0. By symmetry of the velocity
    % profile, the integral closes at 0 exactly.
    p = cumtrapz(t, vel);
end
