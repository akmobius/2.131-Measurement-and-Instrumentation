%% Advanced Cavity Volume Integration with Drift Compensation
% This script integrates flow data while compensating for sensor bias and 
% cumulative drift. It treats the two cavities as independent systems.

% 1. Load the data
filename = 'sensor_data_20260511_150006.csv';
data = readtable(filename);

time_ms = data.time_ms;
f3_raw = data.f3; % Output flow from Cavity 3
f4_raw = data.f4; % Input flow to Cavity 4
t = time_ms / 1000; % Convert to seconds
dt = [0; diff(t)];

% 2. Filtering and Bias Compensation
% Calculate bias from the first 50 samples (assuming idle at start)
bias3 = mean(f3_raw(1:50));
bias4 = mean(f4_raw(1:50));

% Subtract bias and apply a moving average filter to reduce noise
windowSize = 25;
f3_clean = movmean(f3_raw - bias3, windowSize);
f4_clean = movmean(f4_raw - bias4, windowSize);

% 3. Define Integration Parameters
% Leakage factor: Pulls the volume slightly toward 0 at each step.
% 1.0 = pure integration (drifts); 0.99 = stable (resists drift)
leakage = 0.999; 

% Deadband: Treat any flow smaller than this as zero noise
deadband = 0.05; 

% Initial Volumes (Adjust as needed)
v3 = zeros(length(t), 1);
v4 = zeros(length(t), 1);

% Cavity 3 is an output cavity, so it might start full
v3(1) = 50; 
v4(1) = 0;

% 4. Integration Loop
for i = 2:length(t)
    % Process f3 (Output flow)
    flow3 = f3_clean(i);
    if abs(flow3) < deadband, flow3 = 0; end
    
    % Update Cavity 3: V = V_old * leakage - flow * dt
    v3(i) = (v3(i-1) * leakage) - (flow3 * dt(i));
    
    % Process f4 (Input flow)
    flow4 = f4_clean(i);
    if abs(flow4) < deadband, flow4 = 0; end
    
    % Update Cavity 4: V = V_old * leakage + flow * dt
    v4(i) = (v4(i-1) * leakage) + (flow4 * dt(i));
    
    % Non-negative constraint
    if v3(i) < 0, v3(i) = 0; end
    if v4(i) < 0, v4(i) = 0; end
end

% 5. Plotting
figure;

subplot(2,1,1);
plot(t, v3, 'b', 'LineWidth', 1.5);
title('Cavity 3 Volume (Integrated f3 - Output)');
ylabel('Volume (units)');
grid on;

subplot(2,1,2);
plot(t, v4, 'r', 'LineWidth', 1.5);
title('Cavity 4 Volume (Integrated f4 - Input)');
xlabel('Time (seconds)');
ylabel('Volume (units)');
grid on;

figure
plot(t, v3, 'b', 'LineWidth', 1.5);
hold on
plot(t, v4, 'r', 'LineWidth', 1.5);
legend('output', 'input')

%% %% Plotting One Cycle of Cavity Volume
% This script isolates a single cycle and calculates volume with 
% drift correction to ensure the plot is clean and physically realistic.

% 1. Load the dataset
data = readtable('sensor_data_20260511_150006.csv');

% 2. Define the cycle time window (in milliseconds)
% Adjust these values to zoom into different cycles
cycle_start_ms = 11536; 
cycle_end_ms = 12034; 

% Extract the subset of data
idx = data.time_ms >= cycle_start_ms & data.time_ms <= cycle_end_ms;
cycle_data = data(idx, :);

% Extract variables
t_ms = cycle_data.time_ms;
t = (t_ms - t_ms(1)) / 1000; % Time in seconds starting from 0
f3_raw = cycle_data.f3;
f4_raw = cycle_data.f4;

% 3. Filtering and Drift Correction
% Smooth the data with a 15-sample moving average
f3_smooth = movmean(f3_raw, 15);
f4_smooth = movmean(f4_raw, 15);

% To prevent "going crazy", we subtract the mean flow rate of the cycle.
% This ensures the integral starts and ends near the same volume level.
f3_corr = f3_smooth - mean(f3_smooth);
f4_corr = f4_smooth - mean(f4_smooth);

% 4. Integration
dt = [0; diff(t)];
v3 = zeros(size(t));
v4 = zeros(size(t));

% Initial volumes for this cycle
v3(1) = 0; 
v4(1) = 0;

for i = 2:length(t)
    % Cavity 3 Volume (f3 is output)
    v3(i) = v3(i-1) - (f3_corr(i) * dt(i));
    
    % Cavity 4 Volume (f4 is input)
    v4(i) = v4(i-1) + (f4_corr(i) * dt(i));
    
    % Clamp volume at zero
    if v3(i) < 0, v3(i) = 0; end
    if v4(i) < 0, v4(i) = 0; end
end

% 5. Plotting
figure('Position', [100, 100, 800, 600]);

subplot(2,1,1);
plot(t, v3, 'LineWidth', 2, 'Color', [0 0.447 0.741]);
title('Cavity 3: Single Cycle Volume');
ylabel('Volume (units)');
grid on;

subplot(2,1,2);
plot(t, v4, 'LineWidth', 2, 'Color', [0.85 0.325 0.098]);
title('Cavity 4: Single Cycle Volume');
xlabel('Time (seconds)');
ylabel('Volume (units)');
grid on;
