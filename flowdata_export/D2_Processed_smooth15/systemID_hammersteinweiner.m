clear all; close all;
%% 1. Data Import with State-Dependent Inputs (Rate & Integral)
filePattern = 'sensor_data_*.csv';
files = dir(filePattern);
Fs = 200; 
Ts = 1/Fs;
dataList = cell(1, length(files));

for i = 1:length(files)
    tbl = readtable(files(i).name);
    tRaw = tbl.Time_s;
    uRaw = tbl.Input_Flow_Smoothed;
    yRaw = tbl.Output_Flow_Smoothed;
    
    % Uniform resampling
    tUniform = (0 : Ts : tRaw(end))';
    uUniform = interp1(tRaw, uRaw, tUniform, 'linear', 'extrap');
    yUniform = interp1(tRaw, yRaw, tUniform, 'linear', 'extrap');
    
    % INPUT 2: Rate of Change (dU/dt) - Captures Viscoelastic Hysteresis
    uDot = [0; diff(uUniform) / Ts]; 
    
    % INPUT 3: Integral of Flow - Captures Internal Volume/Pressure State
    uIntegral = cumtrapz(tUniform, uUniform); 
    
    % Create a 3-input, 1-output iddata object
    % Inputs: [Primary Flow, Rate, Cumulative Volume]
    tempData = iddata(yUniform, [uUniform, uDot, uIntegral], Ts);
    
    % Detrending centers the data for better optimization
    dataList{i} = detrend(tempData);
end

combinedData = merge(dataList{:});

%% 2. Parameter Configuration
% Estimating delay primarily for the first input
primaryDelay = delayest(combinedData(:,1,1)); 

% nb = zeros, nf = poles, nk = delay for each of the 3 inputs
nb = [2 2 2]; 
nf = [3 3 3]; 
nk = [primaryDelay 0 0]; 

%% 3. Nonlinearity Setup
% idPiecewiseLinear allows the model to "map" the specific stretching 
% curve of your metamaterial.
inputNL = [idPiecewiseLinear('NumberOfUnits', 20), ... % Primary Flow
           idPiecewiseLinear('NumberOfUnits', 10), ... % Rate
           idPiecewiseLinear('NumberOfUnits', 10)];    % Volume/State

outputNL = idPiecewiseLinear('NumberOfUnits', 20);

% Estimation Options
opt = nlhwOptions('SearchMethod', 'auto');
opt.SearchOption.MaxIter = 100;
opt.SearchOption.Tolerance = 1e-6;

%% 4. Model Estimation & Validation
fprintf('Starting 3-input identification...\n');
sys_model = nlhw(combinedData, [nb nf nk], inputNL, outputNL, opt);

figure;
compare(combinedData, sys_model);
title('Final Multi-State Metamaterial Fit');

% View the residual correlation to check for remaining patterns
figure;
resid(combinedData, sys_mowordel);
%% % Use 8 files for training, 2 for testing (to check it's not overfitting)
trainData = merge(dataList{1:8});
valData = merge(dataList{9:10}); 

% Train on the 8 files
sys_model = nlhw(trainData, [nb nf nk], inputNL, outputNL, opt);

% Compare against the 2 UNSEEN files
compare(valData, sys_model);
%% %% 3. Robust Validation Plotting
% [yh, fit] returns cell arrays for multi-experiment data
[yh, fit_cell] = compare(valData, sys_model);

% Extract numeric fit and data for the first validation experiment
% Use {} for cell indexing to avoid "Function not defined for cell" errors
if iscell(fit_cell)
    current_fit = fit_cell{1}; 
else
    current_fit = fit_cell(1);
end

% Accessing data from the first validation iddata object
valExp1 = yh{1}; 
actualExp1 = getexp(valData, 1);

t_plot = actualExp1.SamplingInstants;
y_meas = actualExp1.OutputData;
y_pred = valExp1.OutputData;

figure('Color', 'w', 'Units', 'inches', 'Position', [2, 2, 7, 4.5]);
hold on; grid on;
plot(t_plot, y_meas, 'Color', [0.3 0.3 0.3], 'LineWidth', 1.1, 'DisplayName', 'Experimental');
plot(t_plot, y_pred, 'r--', 'LineWidth', 1.4, 'DisplayName', sprintf('Model (Fit: %.1f%%)', current_fit));

set(gca, 'FontSize', 11, 'TickLabelInterpreter', 'latex', 'Box', 'on');
xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Output Flow (L/min)', 'Interpreter', 'latex', 'FontSize', 12);
title('\textbf{Metamaterial Cavity: Model Validation}', 'Interpreter', 'latex', 'FontSize', 14);
legend('Location', 'best', 'Interpreter', 'latex');
axis tight;

%% 4. Transfer Function Extraction
% Extract the discrete-time linear core of the model
Gz = tf(sys_model.LinearModel);

% Convert to continuous-time (Laplace Domain) using Tustin transform
Gs = d2c(Gz, 'tustin');
[wn, zeta] = damp(Gs);

fprintf('\n--- Continuous-Time Transfer Function ---\n');
display(Gs);
fprintf('Natural Frequency: %.2f rad/s\n', wn(1));
fprintf('Damping Ratio: %.2f\n', zeta(1));
%% %% --- PRESENTATION-READY MODEL PROOF SECTION ---
% This section generates 4 key plots to validate the metamaterial physics.

% 1. Extract validation data
[yh, fit_cell] = compare(valData, sys_model);
if iscell(fit_cell), fit_val = fit_cell{1}; else, fit_val = fit_cell(1); end

valExp = getexp(valData, 1);
t_vec = valExp.SamplingInstants;
u_raw = valExp.u(:,1); 
y_meas = valExp.y;
y_pred = yh{1}.y;
%% Plot A: Time-Domain Validation
figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 7, 4]);
hold on; grid on;
plot(t_vec, y_meas, 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'DisplayName', 'Experimental');
plot(t_vec, y_pred, 'r--', 'LineWidth', 1.5, 'DisplayName', sprintf('Model Fit (%.1f%%)', fit_val));
xlabel('Time (s)'); ylabel('Flow (L/min)');
title('Metamaterial Cavity: Out-of-Sample Validation');
legend('Location', 'best');
set(gca, 'FontSize', 11, 'Box', 'on');
%% Plot B: Hysteresis Loop (Phase Portrait)
% This is your physical proof of the Viscoelastic Damping (uDot input)
figure('Color', 'w', 'Units', 'inches', 'Position', [1, 5, 5, 5]);
hold on; grid on;
plot(u_raw, y_meas, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5, 'DisplayName', 'Experimental');
plot(u_raw, y_pred, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Model');
xlabel('Input Flow (L/min)'); ylabel('Output Flow (L/min)');
title('Hysteresis Capture');
legend('Location', 'best');
%% Plot C: Bode Plot (Frequency Response)
figure('Color', 'w', 'Units', 'inches', 'Position', [6, 5, 6, 5]);
b_opt = bodeoptions;
b_opt.FreqUnits = 'Hz';
b_opt.Grid = 'on';

% Using universal Title string assignment
b_opt.Title.String = 'Linear Dynamics Frequency Response';

% Generate the plot
h = bodeplot(sys_model.LinearModel, b_opt);

% Manual interpreter override after plot generation (Robust Fix)
t_handle = getoptions(h);
% If your version supports it, this will apply the interpreter globally
try
    t_handle.TickLabelInterpreter = 'tex'; % Fallback to standard tex if latex fails
    setoptions(h, t_handle);
catch
    % If still failing, MATLAB handles defaults automatically
end
%% Plot 3: Residual Analysis (Whiteness and Correlation Test)
% This is the scientific proof that no "hidden" physics remain in the error.
figure('Color', 'w', 'Units', 'inches', 'Position', [1, 6, 6, 5]);
resid(valData, sys_model);
% Note: The resid command uses its own built-in formatting. 
% To pass validation, the lines must stay within the blue confidence regions.

%% Plot 4: Nonlinearity Mapping (Input/Output Piecewise Functions)
% This visualizes the physical "stiffening" of the metamaterial walls.
figure('Color', 'w', 'Units', 'inches', 'Position', [7, 6, 6, 5]);
subplot(1,2,1);
plot(sys_model, 'input'); 
title('\textbf{Input Nonlinearity Map}', 'Interpreter', 'latex');
grid on;

subplot(1,2,2);
plot(sys_model, 'output');
title('\textbf{Output Nonlinearity Map}', 'Interpreter', 'latex');
grid on;

