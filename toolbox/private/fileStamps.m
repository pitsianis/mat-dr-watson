function stamps = fileStamps(files)
% FILESTAMPS N-by-2 matrix of [lastModified (ms), size (bytes)] per file.
%   A cheap way to detect that a file changed on disk without re-reading it.
%   Missing files get [0 0].
    files = string(files);
    stamps = zeros(numel(files), 2);
    for i = 1:numel(files)
        jf = java.io.File(char(files(i)));
        stamps(i, :) = [double(jf.lastModified()), double(jf.length())];
    end
end
