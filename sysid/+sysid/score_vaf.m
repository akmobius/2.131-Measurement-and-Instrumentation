function vaf = score_vaf(y_meas, y_pred)
% SCORE_VAF  Variance accounted for (%).
%   VAF = 100 * (1 - var(y_meas - y_pred) / var(y_meas))
%   100 = perfect, 0 = no better than constant.
    e = y_meas(:) - y_pred(:);
    vaf = 100 * (1 - var(e) / max(var(y_meas(:)), eps));
end
