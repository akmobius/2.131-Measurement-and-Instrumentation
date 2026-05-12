function data = load_csv(spec)
% LOAD_CSV  Load one or more CSV files into a unified channel struct.
%
%   data = sysid.load_csv(spec)
%
%   spec is a struct with fields:
%     .files     cell array of CSV paths
%     .roles     cell array (same length as .files) of channel names, OR
%                struct mapping column names -> channel names if a single
%                wide CSV is given
%     .time_col  (optional) name of time column. Default 'time' or first col.
%     .value_col (optional) name of value column for two-col files. Default
%                second column.
%
%   Returns struct `data` with:
%     data.<role>.t   raw time vector (seconds)
%     data.<role>.y   raw signal vector
%     data.fs_native  vector of native sample rates (one per role)
%
%   Two supported input layouts:
%     1) One file per channel, each with [time, value] columns. spec.files
%        and spec.roles are parallel cell arrays.
%     2) Single wide CSV with named columns. spec.files is a 1x1 cell, and
%        spec.roles is a struct: roles.<csv_column_name> = '<role_name>'.

    if ~isfield(spec, 'time_col'),  spec.time_col  = '';  end
    if ~isfield(spec, 'value_col'), spec.value_col = '';  end

    data = struct();
    fs_native = [];

    if isstruct(spec.roles)
        % Wide CSV mode — supports one OR many wide CSVs. Each file may
        % have its own time column; columns are matched to roles by name
        % across all files (first match wins). Each file's time vector is
        % rebased to 0 so independently-captured records align by their
        % relative time, not absolute timestamps.
        roleFields = fieldnames(spec.roles);
        for kf = 1:numel(spec.files)
            T = readtable(spec.files{kf}, 'VariableNamingRule','preserve');
            cols = T.Properties.VariableNames;
            if isempty(spec.time_col)
                tcol = cols{1};
            else
                tcol = spec.time_col;
            end
            if ~ismember(tcol, cols)
                warning('sysid:load_csv:noTimeCol', ...
                    'Time column "%s" not in %s; skipping file.', ...
                    tcol, spec.files{kf});
                continue;
            end
            t = T.(tcol);
            if ~isnumeric(t), t = seconds(t - t(1)); end
            t = double(t(:));
            if max(t) > 1e4, t = t * 1e-3; end   % ms → s if needed
            t = t - t(1);                         % rebase to 0

            for k = 1:numel(roleFields)
                csv_col = roleFields{k};
                role    = spec.roles.(csv_col);
                if ismember(csv_col, cols) && ~isfield(data, role)
                    y = double(T.(csv_col));
                    data.(role).t = t;
                    data.(role).y = y(:);
                    data.(role).file = spec.files{kf};
                    fs_native(end+1) = 1 / median(diff(t)); %#ok<AGROW>
                end
            end
        end
    else
        % One-file-per-channel mode
        for k = 1:numel(spec.files)
            T = readtable(spec.files{k}, 'VariableNamingRule','preserve');
            cols = T.Properties.VariableNames;
            tcol = spec.time_col;
            if isempty(tcol), tcol = cols{1}; end
            vcol = spec.value_col;
            if isempty(vcol), vcol = cols{2}; end
            t = double(T.(tcol));
            if max(t) > 1e4, t = t * 1e-3; end
            y = double(T.(vcol));
            role = spec.roles{k};
            data.(role).t = t(:);
            data.(role).y = y(:);
            data.(role).file = spec.files{k};
            fs_native(end+1) = 1 / median(diff(t)); %#ok<AGROW>
        end
    end

    data.fs_native = fs_native;
end
