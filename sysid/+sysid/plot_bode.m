function fig = plot_bode(frf, varargin)
% PLOT_BODE  Stacked magnitude / phase / coherence² Bode plot with overlay support.
%
%   fig = sysid.plot_bode(frf)
%   fig = sysid.plot_bode(frf, 'Title', 'My Plot', ...
%                              'OverlayFRF', frf2, ...
%                              'OverlayLabel', 'fit', ...
%                              'DwellPoints', pts, ...
%                              'PhaseUnit', 'deg')
%
%   `frf` is the struct returned by sysid.frf_welch.
%   `OverlayFRF` is a struct with fields .f and .H (e.g. fit.H_pred + frf.f),
%   plotted on top of the Welch curves with a dashed line.
%   `DwellPoints` is the struct array from sysid.frf_sine_dwell.

    p = inputParser;
    addParameter(p, 'Title', '');
    addParameter(p, 'OverlayFRF', []);
    addParameter(p, 'OverlayLabel', 'fit');
    addParameter(p, 'DwellPoints', []);
    addParameter(p, 'PhaseUnit', 'deg');
    parse(p, varargin{:});
    R = p.Results;

    phase_scale = strcmpi(R.PhaseUnit,'deg') * (180/pi) + ...
                  strcmpi(R.PhaseUnit,'rad') * 1;

    fig = figure('Color','w','Position',[100 100 720 720]);
    tl = tiledlayout(fig, 3, 1, 'TileSpacing','compact','Padding','compact');
    if ~isempty(R.Title), title(tl, R.Title, 'Interpreter','none'); end

    ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on');
    loglog(ax1, frf.f, frf.mag, '-', 'LineWidth', 1.4, 'DisplayName','Welch H1');
    set(ax1,'XScale','log','YScale','log');
    ylabel(ax1, '|H|');

    ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on');
    semilogx(ax2, frf.f, frf.phase * phase_scale, '-', 'LineWidth', 1.4, ...
             'DisplayName','Welch H1');
    set(ax2,'XScale','log');
    ylabel(ax2, ['phase (' R.PhaseUnit ')']);

    ax3 = nexttile; hold(ax3,'on'); grid(ax3,'on');
    semilogx(ax3, frf.f, frf.coh2, '-', 'LineWidth', 1.4, 'DisplayName','coh^2');
    yline(ax3, 0.5, '--', 'LineWidth', 0.8, 'HandleVisibility','off');
    set(ax3,'XScale','log','YLim',[0 1.05]);
    ylabel(ax3, 'coherence^2'); xlabel(ax3, 'frequency (Hz)');

    if ~isempty(R.OverlayFRF)
        of = R.OverlayFRF;
        loglog(ax1, of.f, abs(of.H), '--', 'LineWidth', 1.4, ...
               'DisplayName', R.OverlayLabel);
        semilogx(ax2, of.f, unwrap(angle(of.H))*phase_scale, '--', ...
               'LineWidth', 1.4, 'DisplayName', R.OverlayLabel);
    end

    if ~isempty(R.DwellPoints)
        dp = R.DwellPoints;
        fs   = [dp.f];
        mags = [dp.mag];
        phs  = [dp.phase];
        coh2 = [dp.coh2];
        plot(ax1, fs, mags, 'o', 'MarkerFaceColor','k', 'MarkerSize',5, ...
             'DisplayName','dwell');
        plot(ax2, fs, phs*phase_scale, 'o', 'MarkerFaceColor','k', ...
             'MarkerSize',5, 'DisplayName','dwell');
        plot(ax3, fs, coh2, 'o', 'MarkerFaceColor','k', 'MarkerSize',5, ...
             'DisplayName','dwell');
    end

    legend(ax1, 'Location','best');
    linkaxes([ax1 ax2 ax3], 'x');
    xlim(ax1, [max(frf.f(2),1e-3), frf.f(end)]);
end
