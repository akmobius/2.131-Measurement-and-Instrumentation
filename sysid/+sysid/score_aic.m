function aic = score_aic(residuals, n_params)
% SCORE_AIC  Akaike Information Criterion (Gaussian residual form).
%   AIC = N*log(SSE/N) + 2*k
%   Lower is better. Use to compare models on the same data.
    e = residuals(:);
    N = numel(e);
    SSE = sum(e.^2);
    aic = N * log(SSE / N) + 2 * n_params;
end
