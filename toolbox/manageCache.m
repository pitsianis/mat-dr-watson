function summaryTable = manageCache(cacheDir, action, options)
% MANAGECACHE Inspects, summarizes, or cleans cached .mat files produced by produceOrLoad.
%
%   summaryTable = manageCache(cacheDir)
%   summaryTable = manageCache(cacheDir, action, Name=Value)
%
%   Inputs:
%       cacheDir - Folder path containing cached .mat files (default: 'cache_data')
%       action   - 'list'  : Inspect all cached runs and check if code is still current (default)
%                  'clean' : Delete stale cache entries whose code dependencies changed
%                  'purge' : Delete ALL cached .mat files in cacheDir
%
%   Name-Value Arguments:
%       FuncHandle - Optional function handle. Restricts the listing and any
%                    deletion to runs of that function; other functions'
%                    files in the same folder are left untouched.
%       DryRun     - Logical flag; if true, reports files to delete without deleting (default: false)
%
%   Each run is checked against the dependency files recorded when it was
%   produced (including ExtraFiles), so no function handle is needed to tell
%   whether it is current. Status values:
%       CURRENT            - all recorded dependencies unchanged
%       STALE_CODE         - a recorded dependency changed      ('clean' deletes)
%       MISSING_DEPS       - a recorded dependency no longer exists, e.g. the
%                            project folder moved                ('clean' keeps)
%       UNKNOWN_CODE_STATE - no dependency information           ('clean' keeps)
%       OLD_FORMAT         - made by an older produceOrLoad whose cache keys
%                            are no longer used; a leftover     ('clean' deletes)
%       INVALID            - file could not be read              ('clean' deletes,
%                            unless FuncHandle is given)
%
%   Output:
%       summaryTable - MATLAB table detailing cached files, parameters, status, and size

    arguments
        cacheDir (1,:) char = 'cache_data'
        action (1,:) char {mustBeMember(action, {'list', 'clean', 'purge'})} = 'list'
        options.FuncHandle = []
        options.DryRun (1,1) logical = false
    end

    if ~isfolder(cacheDir)
        fprintf('[manageCache] Cache directory "%s" does not exist.\n', cacheDir);
        summaryTable = table();
        return;
    end

    files = listCacheFiles(cacheDir);
    if isempty(files)
        fprintf('[manageCache] No cached .mat files found in "%s".\n', cacheDir);
        summaryTable = table();
        return;
    end

    funcFilter = "";
    if ~isempty(options.FuncHandle)
        funcFilter = string(func2str(options.FuncHandle));
    end

    memo = containers.Map('KeyType', 'char', 'ValueType', 'any'); % file -> hash, shared across runs

    nFiles = numel(files);
    fileNames = strings(nFiles, 1);
    funcNames = strings(nFiles, 1);
    paramStrs = strings(nFiles, 1);
    createdAt = strings(nFiles, 1);
    elapsedSec = nan(nFiles, 1);
    sizeKB = nan(nFiles, 1);
    status = strings(nFiles, 1);
    toDelete = false(nFiles, 1);
    keep = true(nFiles, 1);

    for i = 1:nFiles
        fullPath = fullfile(files(i).folder, files(i).name);
        fileNames(i) = string(files(i).name);
        sizeKB(i) = round(files(i).bytes / 1024, 2);

        try
            data = load(fullPath, 'meta');
            meta = data.meta;
            funcNames(i) = string(meta.funcName);
        catch
            if funcFilter ~= ""
                % Cannot tell which function this belongs to: leave it alone.
                keep(i) = false;
                continue;
            end
            funcNames(i) = "CORRUPT_OR_LEGACY";
            status(i) = "INVALID";
            toDelete(i) = strcmp(action, 'clean') || strcmp(action, 'purge');
            continue;
        end

        if funcFilter ~= "" && funcNames(i) ~= funcFilter
            keep(i) = false;
            continue;
        end

        try
            % Display only; ConvertInfAndNaN=false shows Inf/NaN instead of null.
            paramStrs(i) = string(jsonencode(meta.params, 'ConvertInfAndNaN', false));
        catch
            paramStrs(i) = string(serializeValue(meta.params)); % e.g. complex values
        end
        createdAt(i) = string(meta.createdAt);
        elapsedSec(i) = round(meta.elapsedSeconds, 4);
        status(i) = codeStatus(meta, memo);

        if strcmp(action, 'purge')
            toDelete(i) = true;
        elseif strcmp(action, 'clean')
            toDelete(i) = ismember(status(i), ["STALE_CODE", "OLD_FORMAT"]);
        end
    end

    summaryTable = table(fileNames, funcNames, status, elapsedSec, sizeKB, createdAt, paramStrs, ...
        'VariableNames', {'FileName', 'Function', 'Status', 'RunTimeSec', 'SizeKB', 'CreatedAt', 'ParamsJSON'});
    summaryTable = summaryTable(keep, :);

    if strcmp(action, 'clean') || strcmp(action, 'purge')
        deletePaths = fullfile(cacheDir, fileNames(toDelete & keep));
        if isempty(deletePaths)
            fprintf('[manageCache] No files matched criteria for "%s".\n', action);
        elseif options.DryRun
            fprintf('[manageCache] DRY RUN: Would delete %d file(s).\n', numel(deletePaths));
        else
            for k = 1:numel(deletePaths)
                delete(deletePaths(k));
            end
            fprintf('[manageCache] Deleted %d file(s) during "%s".\n', numel(deletePaths), action);
        end
    end
end
