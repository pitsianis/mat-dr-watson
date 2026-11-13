function files = listCacheFiles(cacheDir)
% LISTCACHEFILES Cached result files in cacheDir, excluding in-progress temp files.
    files = dir(fullfile(cacheDir, '*.mat'));
    files = files(~contains({files.name}, '.tmp_'));
end
