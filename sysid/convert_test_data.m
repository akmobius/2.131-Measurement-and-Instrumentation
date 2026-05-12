function convert_test_data(root_dir, cal)
% CONVERT_TEST_DATA  Convert raw test text files into sysid-ready CSVs.
%
%   convert_test_data()                  scans ./ for "Test *" folders
%   convert_test_data(root_dir)          scans the given directory
%   convert_test_data(root_dir, cal)     applies per-channel calibration
%
% Each test folder must contain a .txt with header line:
%   time, pressure1, pressure2, out_flow, in_flow
% (the leading "READY" line and any malformed trailing lines are ignored.)
% Pressure columns are dropped because the sensors weren't connected on
% these runs. Flow columns are passed through the calibration:
%
%      calibrated = raw * scale + offset
%
% Per-channel calibration struct (default values applied if `cal` omitted):
%
%   cal.inlet_air_flow.scale     = 1.0;
%   cal.inlet_air_flow.offset    = 0.0;
%   cal.outlet_water_flow.scale  = 1.0;
%   cal.outlet_water_flow.offset = 0.0;
%
% System ID does not depend on a correct K — gain and offset both
% factor out of the FRF shape, fitted (fn, zeta) are unchanged, and only
% the reported K shifts. So leaving cal at identity is fine for now;
% updating it later just rescales the K column in the comparison table.
%
% The output CSV lives next to the source .txt with the same basename:
%   Test 1 0.5Hz 80mm/Test1.txt  ->  Test 1 0.5Hz 80mm/Test1.csv
%
% Columns are renamed to match the sysid GUI's role auto-guesser:
%   time_s, inlet_air_flow, outlet_water_flow

    if nargin < 1 || isempty(root_dir)
        root_dir = fileparts(mfilename('fullpath'));
    end
    if nargin < 2 || isempty(cal)
        cal = default_cal();
    else
        cal = merge_with_default(cal);
    end

    test_dirs = dir(fullfile(root_dir, 'Test *'));
    test_dirs = test_dirs([test_dirs.isdir]);
    fprintf('Scanning %s — found %d test folders.\n', root_dir, numel(test_dirs));

    for k = 1:numel(test_dirs)
        d = fullfile(root_dir, test_dirs(k).name);
        txts = dir(fullfile(d, '*.txt'));
        if isempty(txts)
            fprintf('  skip %s: no .txt\n', test_dirs(k).name);
            continue;
        end
        src = fullfile(d, txts(1).name);
        [~, base] = fileparts(txts(1).name);
        out = fullfile(d, [base '.csv']);
        convert_one(src, out, cal);
    end
end

% =============================================================================

function convert_one(src, out, cal)
    fid = fopen(src, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);

    lines = regexp(raw, '\r?\n', 'split');
    rows = zeros(0, 3);    % [time_s, inlet_air_flow, outlet_water_flow]
    t0_ms = NaN;
    n_skipped = 0;

    for i = 1:numel(lines)
        line = strtrim(lines{i});
        if isempty(line), continue; end
        if isempty(regexp(line, '^[+-]?\d', 'once'))
            continue;          % header / READY / garbage
        end
        parts = strsplit(line, ',');
        if numel(parts) < 5
            n_skipped = n_skipped + 1;
            continue;
        end
        t_ms     = str2double(parts{1});
        out_raw  = str2double(parts{4});
        in_raw   = str2double(parts{5});
        if any(isnan([t_ms, out_raw, in_raw]))
            n_skipped = n_skipped + 1;
            continue;
        end
        if isnan(t0_ms), t0_ms = t_ms; end
        t_s = (t_ms - t0_ms) / 1000;
        q_in  = in_raw  * cal.inlet_air_flow.scale    + cal.inlet_air_flow.offset;
        q_out = out_raw * cal.outlet_water_flow.scale + cal.outlet_water_flow.offset;
        rows(end+1, :) = [t_s, q_in, q_out]; %#ok<AGROW>
    end

    T = array2table(rows, 'VariableNames', ...
        {'time_s', 'inlet_air_flow', 'outlet_water_flow'});
    writetable(T, out);

    if isempty(rows)
        fprintf('  %s: NO DATA (%d skipped)\n', src, n_skipped);
        return;
    end
    duration = rows(end,1) - rows(1,1);
    fs = (size(rows,1)-1) / max(duration, eps);
    fprintf('  %s: %d rows, %.2f s, fs ~= %.1f Hz (%d skipped)\n', ...
        src, size(rows,1), duration, fs, n_skipped);
end

function c = default_cal()
    c.inlet_air_flow    = struct('scale', 1.0, 'offset', 0.0);
    c.outlet_water_flow = struct('scale', 1.0, 'offset', 0.0);
end

function c = merge_with_default(user_cal)
    c = default_cal();
    fns = fieldnames(user_cal);
    for k = 1:numel(fns)
        if isfield(user_cal.(fns{k}), 'scale')
            c.(fns{k}).scale  = user_cal.(fns{k}).scale;
        end
        if isfield(user_cal.(fns{k}), 'offset')
            c.(fns{k}).offset = user_cal.(fns{k}).offset;
        end
    end
end
