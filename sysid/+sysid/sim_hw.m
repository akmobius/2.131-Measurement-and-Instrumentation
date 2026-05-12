function y_pred = sim_hw(sys, u, fs)
% SIM_HW  Simulate an idnlhw Hammerstein–Wiener model on a new input.
%   y_pred = sysid.sim_hw(sys, u, fs)
%
% Returns the model's free-run prediction of the output for input `u`.
    Ts = 1/fs;
    data = iddata([], u(:), Ts);
    y_dat = sim(sys, data);
    y_pred = y_dat.OutputData;
end
