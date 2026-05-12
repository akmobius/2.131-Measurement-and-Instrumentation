function y = sim_ct(num, den, u, fs)
% SIM_CT  Simulate a continuous-time transfer function on a discrete input.
%   y = sysid.sim_ct(num, den, u, fs)
%
% Discretizes H(s) = polyval(num,s)/polyval(den,s) via bilinear (Tustin)
% transform at sample rate fs, then filters u with the resulting digital
% IIR. No Control System Toolbox dependency — only bilinear + filter
% (Signal Processing Toolbox).

    [bd, ad] = bilinear(num, den, fs);
    y = filter(bd, ad, u(:));
end
