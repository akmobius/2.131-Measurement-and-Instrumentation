%% Multi-Frequency System Identification: Metamaterial Heart
% Purpose: Identify a single transfer function across multiple pump frequencies
% Input: dp1/dt (Rate of Pressure Change)
% Output: f3 (Water Flow)

clear; clc; close all;

% 1. Define Data Files
files = {
    'sensor_data_20260511_150006.csv', ...
    'sensor_data_20260511_150213.csv', ...
    'sensor_data_20260511_150449.csv', ...
    'sensor_data_20260511_150712.csv', ...
    'sensor_data_20260511_150843.csv'
};

fs = 250; % Resampling frequency (Hz)
Ts = 1/fs;
data_collection = {};

fprintf('Synchronizing and preprocessing all experiments...\n');

% 2. Preprocessing Loop
for i = 1:length(files)
    raw = readtable(files{i});
    t_raw = raw.time_ms / 1000;
    
    % Interpolate to common time grid
    t_common = (min(t_raw):Ts:max(t_raw))';
    p1 = interp1(t_raw, raw.p1, t_common, 'linear', 'extrap');
    f3 = interp1(t_raw, raw.f3, t_common, 'linear', 'extrap');
    
    % Feature Engineering: Derivative of Pressure
    % This represents the hydraulic "driving force"
    dp1 = [0; diff(p1)] / Ts; 
    
    % Create individual experiment object
    exp_data = iddata(f3, dp1, Ts);
    exp_data.ExperimentName = sprintf('Freq_Run_%d', i);
    
    % Detrend each experiment individually to remove sensor bias
    data_collection{i} = detrend(exp_data);
end

% 3. Merge All Experiments
% This creates one object containing all frequency data
z_all = merge(data_collection{:});

% 4. Estimate a Single Global Transfer Function
% np = number of poles, nz = number of zeros
% 'IODelay', NaN allows MATLAB to find the transport delay across all sets
fprintf('Estimating Global Transfer Function...\n');
np = 3; 
nz = 2;
sys_global = tfest(z_all, np, nz, 'IODelay', NaN);

fprintf('\nIdentified Global Transfer Function:\n');
disp(sys_global);

% 5. Evaluate Performance
figure('Name', 'Global Model Validation');
compare(z_all, sys_global);
title('Global Model Fit Across All Pump Frequencies');

figure('Name', 'Frequency Response');
bode(sys_global);
grid on;
title('Bode Plot: Metamaterial Heart Dynamics');

% 6. Save the resulting model
save('Global_Heart_Model.mat', 'sys_global', 'z_all');
fprintf('Identification complete. Global model saved.\n');