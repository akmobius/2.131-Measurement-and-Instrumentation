function y_pred = sim_narx(sys, u, fs)
% SIM_NARX  Run free-simulation of an idnlarx model on a new input.
%   y_pred = sysid.sim_narx(sys, u, fs)
    Ts = 1/fs;
    data = iddata([], u(:), Ts);
    y_dat = sim(sys, data);
    y_pred = y_dat.OutputData;
end
