function out = runWithData(params)
% Test fixture: reads a data file (tracked via ExtraFiles) and returns
% result fields whose names clash with a parameter and a bookkeeping column.
    s = str2double(fileread(fullfile(fileparts(mfilename('fullpath')), 'data', 'scale.txt')));
    out.value = s * params.alpha;
    out.alpha = -1;
    out.Status = "mine";
end
