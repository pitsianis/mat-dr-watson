function [result, meta] = produceOrLoad(funcHandle, params, cacheDir, options)
% PRODUCEORLOAD Caches MATLAB simulation results based on parameters and code dependencies.
%
%   [result, meta] = produceOrLoad(funcHandle, params, cacheDir)
%   [result, meta] = produceOrLoad(funcHandle, params, cacheDir, Name=Value)
%
%   Inputs:
%       funcHandle - Handle to a named function, e.g. @simulateDecay.
%                    Anonymous functions (@(p) ...) and nested functions are
%                    rejected: values they capture are invisible to the cache.
%                    Put every setting the run depends on into params instead.
%       params     - Struct of input parameters for the simulation. Field
%                    values may be numbers, logicals, text, cells, or structs.
%       cacheDir   - Folder path where cached .mat files are stored
%
%   Name-Value Arguments:
%       ForceRun   - Logical flag to bypass cache and recompute (default: false)
%       ExtraFiles - Cell array or string array of extra data files to hash (default: {}).
%                    Relative paths are resolved from the current folder.
%       Verbose    - Logical flag to print cache hits/misses (default: true)
%
%   Outputs:
%       result     - Output returned by funcHandle(params)
%       meta       - Struct containing cache status, file path, hashes, and timestamps

    arguments
        funcHandle (1,1) function_handle
        params (1,1) struct
        cacheDir (1,:) char = 'cache_data'
        options.ForceRun (1,1) logical = false
        options.ExtraFiles string = string.empty(1,0)
        options.Verbose (1,1) logical = true
    end

    funcType = functions(funcHandle).type;
    if ismember(funcType, {'anonymous', 'nested'})
        error('produceOrLoad:UnsupportedFunction', ...
            ['produceOrLoad needs a handle to a named function, such as @simulateDecay, ' ...
             'not a %s function (%s). Values captured by such a function are not part ' ...
             'of the cache key, so changing them would silently return old results. ' ...
             'Move those values into the params struct instead.'], funcType, func2str(funcHandle));
    end

    if ~isfolder(cacheDir)
        mkdir(cacheDir);
    end

    % 1. Compute canonical parameter hash. serializeValue is type-aware
    %    (Inf vs NaN, int8(1) vs 1, 'x' vs "x" differ) and ignores field order.
    canonParams = canonicalizeStruct(params);
    paramHash = sha256String(serializeValue(canonParams));

    % 2. Discover and hash code dependencies (cached in-memory, revalidated by file timestamps)
    extraFiles = string(options.ExtraFiles(:));
    missingExtra = extraFiles(~isfile(extraFiles));
    if ~isempty(missingExtra)
        error('produceOrLoad:MissingExtraFile', 'ExtraFiles not found: %s', strjoin(missingExtra, ', '));
    end
    extraFiles = absolutePaths(extraFiles);
    [codeHash, depFiles] = getDependencyHash(funcHandle, extraFiles);

    % 3. Build deterministic cache key and file path
    funcName = regexprep(func2str(funcHandle), '[^a-zA-Z0-9_]', '_');
    combinedHash = sha256String([paramHash '_' codeHash]);
    shortHash = combinedHash(1:16);
    cacheFile = fullfile(cacheDir, sprintf('%s_%s.mat', funcName, shortHash));

    % 4. Load from disk if cache hit
    if isfile(cacheFile) && ~options.ForceRun
        loadedData = load(cacheFile, 'result', 'meta');
        result = loadedData.result;
        meta = loadedData.meta;
        if ~isfield(meta, 'dependencies') || ~isequal(sort(string(meta.dependencies(:))), sort(string(depFiles(:))))
            % Same code content, but the files now live elsewhere (e.g. the
            % project folder was moved): record the current paths so
            % manageCache/collectResults can verify this run again.
            meta.dependencies = depFiles;
            meta.cacheFile = cacheFile;
            meta.fromCache = false;
            atomicSave(cacheFile, result, meta);
        end
        meta.fromCache = true;
        if options.Verbose
            fprintf('[produceOrLoad] CACHE HIT : %s\n', cacheFile);
        end
        return;
    end

    % 5. Execute simulation on cache miss
    if options.Verbose
        fprintf('[produceOrLoad] CACHE MISS: Running %s -> %s\n', funcName, cacheFile);
    end
    tStart = tic;
    result = funcHandle(params);
    elapsedSec = toc(tStart);

    % 6. Package metadata
    meta = struct();
    meta.fromCache = false;
    meta.cacheFile = cacheFile;
    meta.funcName = func2str(funcHandle);
    meta.params = canonParams;
    meta.paramHash = paramHash;
    meta.codeHash = codeHash;
    meta.combinedHash = combinedHash;
    meta.dependencies = depFiles;
    meta.elapsedSeconds = elapsedSec;
    meta.createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    meta.keyVersion = 2;   % cache-key format; files without it are reported as OLD_FORMAT

    % 7. Atomic save (write to unique temp file first for parallel safety)
    atomicSave(cacheFile, result, meta);
end

function atomicSave(cacheFile, result, meta) %#ok<INUSD> (saved by name)
    tmpFile = sprintf('%s.tmp_%s.mat', cacheFile, char(java.util.UUID.randomUUID));
    save(tmpFile, 'result', 'meta', '-v7.3');
    movefile(tmpFile, cacheFile, 'f');
end

function sOut = canonicalizeStruct(sIn)
    fields = sort(fieldnames(sIn));
    sOut = struct();
    for i = 1:numel(fields)
        f = fields{i};
        val = sIn.(f);
        if isstruct(val) && isscalar(val)
            sOut.(f) = canonicalizeStruct(val);
        else
            sOut.(f) = val;
        end
    end
end

function [codeHash, depFiles] = getDependencyHash(funcHandle, extraFiles)
% The dependency list and hash are cached in memory per function, because
% requiredFilesAndProducts is slow. Every call re-checks the modification time
% and size of each cached dependency, so an edited file is picked up
% immediately, including on parallel workers, which have their own copy of
% this persistent cache that `clear produceOrLoad` on the client cannot reach.
    persistent depCache
    if isempty(depCache)
        depCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

    funcInfo = functions(funcHandle);
    if ~isempty(funcInfo.file)
        cacheKey = [funcInfo.file '|' char(strjoin(extraFiles, ';'))];
    else
        cacheKey = [func2str(funcHandle) '|' char(strjoin(extraFiles, ';'))];
    end

    if isKey(depCache, cacheKey)
        cached = depCache(cacheKey);
        if isequal(fileStamps(cached.depFiles), cached.stamps)
            codeHash = cached.codeHash;
            depFiles = cached.depFiles;
            return;
        end
        % A dependency changed on disk: rediscover dependencies (the edit may
        % have added or removed calls) and rehash.
    end

    if ~isempty(funcInfo.file) && isfile(funcInfo.file)
        reqFiles = matlab.codetools.requiredFilesAndProducts(funcInfo.file);
    else
        reqFiles = {};
    end

    allFiles = unique([string(reqFiles(:)); extraFiles(:)]);
    allFiles = allFiles(allFiles ~= "");

    % Stamp before hashing: if a file changes mid-hash, the next call sees a
    % different stamp and rehashes.
    stamps = fileStamps(allFiles);
    codeHash = hashFileList(allFiles);
    depFiles = cellstr(allFiles);

    depCache(cacheKey) = struct('codeHash', codeHash, 'depFiles', {depFiles}, 'stamps', stamps);
end

function p = absolutePaths(p)
% Store ExtraFiles as absolute paths so manageCache/collectResults can find
% them regardless of the current folder.
    for i = 1:numel(p)
        d = dir(p(i));
        p(i) = string(fullfile(d.folder, d.name));
    end
end
