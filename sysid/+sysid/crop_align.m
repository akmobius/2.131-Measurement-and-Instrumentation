function data = crop_align(data, output_role, t_out_start, t_out_end)
% CROP_ALIGN  Per-file cropping that aligns input and output channels.
%
%   data = sysid.crop_align(data, output_role, t_out_start, t_out_end)
%
% Behavior:
%   * Channels from the same source file as `output_role` are cropped to
%     the activity window [t_out_start, t_out_end] and rebased so the
%     window starts at 0.
%   * Channels from a different source file are cropped to keep the first
%     `t_out_end - t_out_start` seconds (their own t=0 is the start of
%     the synthesized excitation, so it should already line up with the
%     output's activity-start).
%
% Pass `t_out_end <= 0` to use the output channel's full duration; pass
% `t_out_start = 0` to disable left-cropping.
%
% Required: `data.(role).file` must be populated by load_csv so each
% channel knows its source.

    if ~isfield(data, output_role)
        error('sysid:crop_align:noOutputRole', ...
              'Output role "%s" not present in data struct.', output_role);
    end
    if ~isfield(data.(output_role), 'file')
        error('sysid:crop_align:noFileTag', ...
              'Channel "%s" missing .file tag — re-load with the updated load_csv.', ...
              output_role);
    end

    out_file = data.(output_role).file;
    out_t    = data.(output_role).t;

    if t_out_start < 0,                         t_out_start = 0;        end
    if t_out_end   <= 0 || t_out_end > out_t(end), t_out_end = out_t(end); end
    if t_out_end <= t_out_start
        error('sysid:crop_align:badWindow', ...
              'Crop window invalid: start=%.3f end=%.3f', t_out_start, t_out_end);
    end
    win_dur = t_out_end - t_out_start;

    roles = setdiff(fieldnames(data), {'fs_native'});
    fs_native_new = [];
    padded_files = {};
    for k = 1:numel(roles)
        r = roles{k};
        ch = data.(r);
        if strcmp(ch.file, out_file)
            % Same file as output → crop to activity window
            keep = ch.t >= t_out_start & ch.t <= t_out_end;
            ch.t = ch.t(keep) - t_out_start;
            ch.y = ch.y(keep);
        else
            % Different file (e.g. synthesized input).
            % Crop from t=0 to t=win_dur. If the input is shorter than
            % win_dur, zero-pad the tail — physically: the controller
            % has stopped applying stimulus, so the input is 0 from
            % then on. This lets the output's response continue past
            % the end of the input.
            native_dur = ch.t(end);
            if native_dur >= win_dur
                keep = ch.t <= win_dur;
                ch.t = ch.t(keep);
                ch.y = ch.y(keep);
            else
                dt = median(diff(ch.t));
                t_pad = (native_dur + dt : dt : win_dur)';
                if ~isempty(t_pad)
                    ch.t = [ch.t; t_pad];
                    ch.y = [ch.y; zeros(numel(t_pad), 1)];
                end
                padded_files{end+1} = sprintf('%s: %.2f s → %.2f s', ...
                    r, native_dur, win_dur); %#ok<AGROW>
            end
        end
        if numel(ch.t) < 2
            error('sysid:crop_align:tooShort', ...
                  'Channel "%s" has <2 samples after crop.', r);
        end
        data.(r) = ch;
        fs_native_new(end+1) = 1 / median(diff(ch.t)); %#ok<AGROW>
    end
    data.fs_native = fs_native_new;

    if ~isempty(padded_files)
        fprintf('[crop_align] Zero-padded input channel(s) to match window:\n  %s\n', ...
                strjoin(padded_files, sprintf('\n  ')));
    end
end
