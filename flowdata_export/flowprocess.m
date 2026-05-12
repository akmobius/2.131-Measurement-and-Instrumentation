% 1. Setup Directories
inputFolder = 'D2';
outputFolder = 'D2_Processed';

% Create the output folder if it doesn't exist
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Get a list of all CSV files in the input folder
fileList = dir(fullfile(inputFolder, '*.csv'));
numFiles = length(fileList);

if numFiles == 0
    disp('No CSV files found in the specified folder.');
    return;
end

% 2. Setup Figure
% Calculate how many rows we need for 2 columns
numRows = ceil(numFiles / 3); 
% Make the figure a bit wider to accommodate two columns
figure('Name', 'Half-Cycle Analysis', 'Position', [100, 50, 1200, 250 * numRows]);

% Variables to track axes handles and the maximum time duration
ax = gobjects(numFiles, 1);
max_duration = 0;

% Smoothing parameter
windowSize = 15; 

% 3. Loop through each file
for k = 1:numFiles
    filename = fileList(k).name;
    filepath = fullfile(inputFolder, filename);
    
    % --- A. IMPORT DATA ---
    data = readtable(filepath);
    time_s = data.time_ms / 1000; 
    
    flow_out_raw = -data.f3;
    flow_in_raw  = -data.f4; 
    
    % --- B. ZERO OUT (Based on first ~1 second) ---
    idx_1s = time_s <= (time_s(1) + 1.0);
    baseline_in = mean(flow_in_raw(idx_1s));
    baseline_out = mean(flow_out_raw(idx_1s));
    
    flow_in_zeroed = flow_in_raw - baseline_in;
    flow_out_zeroed = flow_out_raw - baseline_out;
    
    % --- C. SMOOTH DATA ---
    flow_in_smooth = smoothdata(flow_in_zeroed, 'gaussian', windowSize);
    flow_out_smooth = smoothdata(flow_out_zeroed, 'gaussian', windowSize);
    
    % --- D. CROP THE HALF CYCLE ---
    
    % 1. Find the FIRST significant minimum (main peak of the down-stroke)
    local_mins_in = find(islocalmin(flow_in_smooth) & (flow_in_smooth < -2));
    if isempty(local_mins_in)
        [min_val_in, min_idx_in] = min(flow_in_smooth); 
    else
        min_idx_in = local_mins_in(1); 
        min_val_in = flow_in_smooth(min_idx_in);
    end
    
    local_mins_out = find(islocalmin(flow_out_smooth) & (flow_out_smooth < -2));
    if isempty(local_mins_out)
        [min_val_out, min_idx_out] = min(flow_out_smooth); 
    else
        min_idx_out = local_mins_out(1); 
        min_val_out = flow_out_smooth(min_idx_out);
    end
    
    % 2. Define independent noise floors for the START
    noise_floor_in = min(-0.15, min_val_in * 0.02);
    noise_floor_out = min(-0.15, min_val_out * 0.02);
    
    % 3. START: Scan backwards to find where EACH signal drops
    start_idx_in = find(flow_in_smooth(1:min_idx_in) >= noise_floor_in, 1, 'last');
    if isempty(start_idx_in), start_idx_in = 1; end
        
    start_idx_out = find(flow_out_smooth(1:min_idx_out) >= noise_floor_out, 1, 'last');
    if isempty(start_idx_out), start_idx_out = 1; end
    
    start_idx = min(start_idx_in, start_idx_out);
    
    % 4. END: Scan forwards from the INPUT peak to find where it returns to zero
    end_idx = min_idx_in + find(flow_in_smooth(min_idx_in:end) >= 0, 1, 'first') - 1;
    if isempty(end_idx)
        end_idx = length(flow_in_smooth); 
    end
    
    % Extract the cropped data
    crop_time = time_s(start_idx:end_idx);
    crop_time = crop_time - crop_time(1); % Force relative time starting at 0s
    
    % Update the maximum duration found so far for the unified timescale
    max_duration = max(max_duration, crop_time(end));
    
    crop_in = flow_in_smooth(start_idx:end_idx);
    crop_out = flow_out_smooth(start_idx:end_idx);
    
    % --- E. CALCULATE FREQUENCY ---
    half_period = crop_time(end) - crop_time(1);
    full_period = 2 * half_period;
    freq = 1 / full_period;
    
    % --- F. PLOT (2 Columns) ---
    ax(k) = subplot(numRows, 3, k); % Use numRows and 2 columns
    plot(crop_time, crop_out, 'b-', 'LineWidth', 1.5); hold on;
    plot(crop_time, crop_in, 'r-', 'LineWidth', 1.5);
    
    title(sprintf('Speed: %.2f Hz | File: %s', freq, filename), 'Interpreter', 'none', 'FontSize', 9);
    grid on;
    ylabel('Flow Rate');
    
    % Only add X-labels to the bottom plots for a cleaner look
    if k >= (numFiles - 1)
        xlabel('Relative Time (s)');
    end
    hold off;
    
    % --- G. EXPORT TO NEW CSV ---
    [~, name, ~] = fileparts(filename);
    out_filename = sprintf('%s_%.2fHz.csv', name, freq);
    out_filepath = fullfile(outputFolder, out_filename);
    
    out_table = table(crop_time, crop_in, crop_out, ...
        'VariableNames', {'Time_s', 'Input_Flow_Smoothed', 'Output_Flow_Smoothed'});
    writetable(out_table, out_filepath);
    
    fprintf('Processed: %s -> %.2f Hz\n', filename, freq);
end

% --- H. UNIFY TIMESCALE ---
% Apply the exact same X-axis limits to every single subplot
set(ax, 'XLim', [0, max_duration]);

% Link the X-axes so panning/zooming on one updates all of them simultaneously
linkaxes(ax, 'x');

disp('All files processed and exported to the D2_Processed folder!');
