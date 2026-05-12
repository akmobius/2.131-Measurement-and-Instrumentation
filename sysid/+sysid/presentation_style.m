function presentation_style(fig)
% PRESENTATION_STYLE  Apply slide-friendly defaults to a figure: larger
% fonts, thicker lines, white background, light grids on every axes.
%
%   sysid.presentation_style(fig)

    if nargin < 1 || isempty(fig), fig = gcf; end
    set(fig, 'Color', 'w');

    axs = findall(fig, 'Type', 'axes');
    for k = 1:numel(axs)
        ax = axs(k);
        set(ax, 'FontSize', 12, ...
                'FontName','Helvetica', ...
                'LineWidth', 1.0, ...
                'GridAlpha', 0.25, ...
                'MinorGridAlpha', 0.15, ...
                'Box', 'on', ...
                'TickDir', 'out');
        grid(ax, 'on');
    end

    lines = findall(fig, 'Type', 'line');
    for k = 1:numel(lines)
        ls = get(lines(k), 'LineStyle');
        if strcmp(ls, 'none')
            continue;   % marker-only plot — leave alone
        end
        if get(lines(k), 'LineWidth') < 1.4
            set(lines(k), 'LineWidth', 1.6);
        end
    end

    txts = findall(fig, 'Type', 'text');
    for k = 1:numel(txts)
        set(txts(k), 'FontSize', 12, 'FontName','Helvetica');
    end
end
