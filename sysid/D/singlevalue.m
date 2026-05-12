%% Isolated Flow Cycle Visualization
% Purpose: Extract and plot exactly one "mountain" from the water flow (f3)

clear; clc; close all;

% 1. Load data
filename = 'sensor_data_20260511_150712.csv';
data = readtable(filename);
t = data.time_ms / 1000;
f3 = data.f3;

% 2. Smooth the signal to identify the cycle bounds clearly
% We use a moving average to find the troughs, but plot the raw data
f_smooth = movmean(f3, 20); 

% 3. Find the main peak in the flow
[~, peak_idx] = max(f_smooth);

% 4. Find the start of the pulse (first trough before the peak)
dt = median(diff(t));
look_limit = round(0.5 / dt); % search within 0.5s of the peak
start_search = max(1, peak_idx - look_limit);
[~, rel_start] = min(f_smooth(start_search:peak_idx));
actual_start_idx = start_search + rel_start - 1;

% 5. Find the end of the pulse (first trough after the peak)
end_search = min(length(f_smooth), peak_idx + look_limit);
[~, rel_end] = min(f_smooth(peak_idx:end_search));
actual_end_idx = peak_idx + rel_end - 1;

% 6. Extract the single flow mountain
t_zoom = t(actual_start_idx:actual_end_idx) - t(actual_start_idx);
f_zoom = f3(actual_start_idx:actual_end_idx);

% 7. Plotting
figure('Color', 'w', 'Name', 'Single Flow Pulse');
plot(t_zoom, f_zoom, 'Color', [0 0.5 0], 'LineWidth', 2.5); % Dark green
xlabel('Time (seconds)');
ylabel('Water Flow (f3)');
title(['Zoomed Single Flow Cycle: ', filename]);
grid on;
set(gca, 'FontSize', 12);

fprintf('Flow cycle isolated. Duration: %.3f seconds\n', max(t_zoom));
%% %% Single Cycle System Identification: The "Mountain" Fit
% Purpose: Identify a high-fidelity model for a single hydraulic event
% Input: Pressure (p1)
% Output: Water Flow (f3)

clear; clc; close all;

% 1. Load the data
filename = 'sensor_data_20260511_150712.csv'; 
data = readtable(filename);
t = data.time_ms / 1000;
p1 = data.p1;
f3 = data.f3;

% 2. Isolate the "Mountain" Cycle
% We smooth slightly to find clean troughs (local minima)
f_smooth = movmean(f3, 15);
[~, peak_idx] = max(f_smooth);
dt = median(diff(t));
search_limit = round(0.5 / dt);

% Trough-to-Trough extraction
start_search = max(1, peak_idx - search_limit);
[~, rel_start] = min(f_smooth(start_search:peak_idx));
idx_start = start_search + rel_start - 1;

end_search = min(length(f_smooth), peak_idx + search_limit);
[~, rel_end] = min(f_smooth(peak_idx:end_search));
idx_end = peak_idx + rel_end - 1;

% 3. Format Data for System ID
t_iso = t(idx_start:idx_end) - t(idx_start);
u_iso = p1(idx_start:idx_end);
y_iso = f3(idx_start:idx_end);

% Remove DC offset (detrend) so the model fits the pulse shape, not the bias
z = iddata(y_iso, u_iso, dt);
z = detrend(z);

% 4. Estimate the Transfer Function (TF)
% A 2nd order system is standard for mass-spring-damper metamaterials
np = 2; % Number of poles
nz = 1; % Number of zeros
sys_id = tfest(z, np, nz);

% 5. Analyze and Plot
figure('Color', 'w', 'Name', 'Single Cycle System ID');
compare(z, sys_id);
title(sprintf('Model Fit on Single Cycle: %s', filename));
grid on;

% Extract physical parameters
[wn, zeta] = damp(sys_id);
fprintf('\n--- Identified Parameters ---\n');
fprintf('Natural Frequency (wn): %.2f rad/s\n', wn(1));
fprintf('Damping Ratio (zeta): %.2f\n', zeta(1));
disp(sys_id);

% 6. Save the model
save('Single_Pulse_Model.mat', 'sys_id', 'z');
%% %% Single Cycle Input-Output Visualization
% Purpose: Plot raw pressure and flow together for a single cycle

clear; clc; close all;

% 1. Load the data
filename = 'sensor_data_20260511_150712.csv'; 
data = readtable(filename);
t = data.time_ms / 1000;
p1 = data.p1;
f3 = data.f3;

% 2. Isolate the "Mountain" Cycle using Flow Peaks
f_smooth = movmean(f3, 15);
[~, peak_idx] = max(f_smooth);
dt = median(diff(t));
search_limit = round(0.5 / dt);

% Find troughs around the peak
start_search = max(1, peak_idx - search_limit);
[~, rel_start] = min(f_smooth(start_search:peak_idx));
idx_start = start_search + rel_start - 1;

end_search = min(length(f_smooth), peak_idx + search_limit);
[~, rel_end] = min(f_smooth(peak_idx:end_search));
idx_end = peak_idx + rel_end - 1;

% 3. Extract the segment
t_iso = t(idx_start:idx_end) - t(idx_start);
p_iso = p1(idx_start:idx_end);
f_iso = f3(idx_start:idx_end);

% 4. Dual-Axis Plotting
figure('Color', 'w', 'Name', 'Input-Output Relationship');
yyaxis left
plot(t_iso, p_iso, 'b-', 'LineWidth', 2);
ylabel('Pressure (p1)');
grid on;

yyaxis right
plot(t_iso, f_iso, 'Color', [0 0.5 0], 'LineWidth', 2);
ylabel('Water Flow (f3)');

xlabel('Time (seconds)');
title(['Single Pulse Input vs Output: ', filename]);
legend('Pressure (Input)', 'Flow (Output)', 'Location', 'best');

