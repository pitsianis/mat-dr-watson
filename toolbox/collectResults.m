function tbl = collectResults(cacheDir, options)
% COLLECTRESULTS Gathers all cached runs into one table for analysis.
%   Replicates DrWatson.jl's collect_results functionality in MATLAB.
%
%   tbl = collectResults(cacheDir)
%   tbl = collectResults(cacheDir, Name=Value)
%
%   One row per cached run, sorted by parameter values. Columns, in order:
%     * one per parameter (nested structs are flattened: p.solver.tol -> solver_tol)
%     * one per field of the result struct (flattened the same way; a
%       non-struct result becomes a single column named "result"; a result
%       field with the same name as a parameter or bookkeeping column is renamed "result_<name>")
%     * Function, Status, RunTimeSec, CreatedAt, File
%
%   Column types: numeric/logical scalars -> double column (NaN when a run
%   lacks the field); text scalars -> string column (<missing> when absent);
%   anything else (vectors, matrices, structs) -> cell column.
%
%   Name-Value Arguments:
%       FuncHandle  - Only collect runs of this function (default: all)
%       OnlyCurrent - Only collect runs whose code dependencies are unchanged
%                     (Status == "CURRENT") (default: false)
%       Verbose     - Print a summary line (default: true)
%
%   Example:
%       tbl = collectResults('cache_data', FuncHandle=@simulateDecay, OnlyCurrent=true);
%       scatter(tbl.alpha, tbl.finalValue)

    arguments
        cacheDir (1,:) char = 'cache_data'
        options.FuncHandle = []
        options.OnlyCurrent (1,1) logical = false
        options.Verbose (1,1) logical = true
    end

    tbl = table();
    if ~isfolder(cacheDir)
        fprintf('[collectResults] Cache directory "%s" does not exist.\n', cacheDir);
        return;
    end

    funcFilter = "";
    if ~isempty(options.FuncHandle)
        funcFilter = string(func2str(options.FuncHandle));
    end

    files = listCacheFiles(cacheDir);
    memo = containers.Map('KeyType', 'char', 'ValueType', 'any');

    rows = {};          % each row: struct with fields names (string), values (cell)
    nSkippedStale = 0;
    for i = 1:numel(files)
        fullPath = fullfile(files(i).folder, files(i).name);
        try
            data = load(fullPath, 'result', 'meta');
            meta = data.meta;
            result = data.result;
        catch err
            warning('collectResults:Unreadable', 'Skipping unreadable file %s (%s)', files(i).name, err.message);
            continue;
        end

        if funcFilter ~= "" && string(meta.funcName) ~= funcFilter
            continue;
        end

        st = codeStatus(meta, memo);
        if options.OnlyCurrent && st ~= "CURRENT"
            nSkippedStale = nSkippedStale + 1;
            continue;
        end

        [pNames, pVals] = flattenStruct(meta.params, "");
        if isstruct(result) && isscalar(result)
            [rNames, rVals] = flattenStruct(result, "");
        else
            rNames = "result";
            rVals = {result};
        end
        clash = ismember(rNames, [pNames, "Function", "Status", "RunTimeSec", "CreatedAt", "File"]);
        rNames(clash) = "result_" + rNames(clash);

        names = [pNames, rNames, "Function", "Status", "RunTimeSec", "CreatedAt", "File"];
        vals  = [pVals,  rVals,  {string(meta.funcName), st, meta.elapsedSeconds, ...
                                  string(meta.createdAt), string(fullPath)}];
        rows{end+1} = struct('names', names, 'vals', {vals}); %#ok<AGROW>
        rows{end}.nParams = numel(pNames);
    end

    nRows = numel(rows);
    if nRows == 0
        if options.Verbose
            fprintf('[collectResults] No matching runs in "%s".\n', cacheDir);
        end
        return;
    end

    % Column order: parameters first, then results, then bookkeeping columns.
    metaCols = ["Function", "Status", "RunTimeSec", "CreatedAt", "File"];
    paramCols = strings(1, 0);
    resultCols = strings(1, 0);
    for r = 1:nRows
        n = rows{r}.names;
        paramCols = [paramCols, setdiff(n(1:rows{r}.nParams), paramCols, 'stable')]; %#ok<AGROW>
        resNames = n(rows{r}.nParams+1:end-numel(metaCols));
        resultCols = [resultCols, setdiff(resNames, [paramCols resultCols], 'stable')]; %#ok<AGROW>
    end
    allCols = [paramCols, resultCols, metaCols];

    for c = 1:numel(allCols)
        vals = cell(nRows, 1);
        present = false(nRows, 1);
        for r = 1:nRows
            idx = find(rows{r}.names == allCols(c), 1);
            if ~isempty(idx)
                vals{r} = rows{r}.vals{idx};
                present(r) = true;
            end
        end
        tbl.(allCols(c)) = buildColumn(vals, present);
    end

    % Sort rows by the parameter columns that hold scalars (cache files are
    % named by hash, so the file order is meaningless).
    sortCols = paramCols(arrayfun(@(name) ~iscell(tbl.(name)), paramCols));
    if ~isempty(sortCols)
        tbl = sortrows(tbl, cellstr(sortCols));
    end

    if options.Verbose
        msg = sprintf('[collectResults] Collected %d run(s) from "%s"', nRows, cacheDir);
        if nSkippedStale > 0
            msg = sprintf('%s (skipped %d non-current)', msg, nSkippedStale);
        end
        fprintf('%s.\n', msg);
    end
end

function [names, vals] = flattenStruct(s, prefix)
% Flatten a scalar struct into parallel lists of names and values;
% nested scalar structs become prefix_field names.
    names = strings(1, 0);
    vals = cell(1, 0);
    fields = fieldnames(s);
    for i = 1:numel(fields)
        v = s.(fields{i});
        if prefix == ""
            name = string(fields{i});
        else
            name = prefix + "_" + fields{i};
        end
        if isstruct(v) && isscalar(v) && ~isempty(fieldnames(v))
            [n2, v2] = flattenStruct(v, name);
            names = [names, n2]; %#ok<AGROW>
            vals = [vals, v2];   %#ok<AGROW>
        else
            names(end+1) = name; %#ok<AGROW>
            vals{end+1} = v;     %#ok<AGROW>
        end
    end
end

function col = buildColumn(vals, present)
    n = numel(vals);
    pv = vals(present);
    isNumScalar = @(v) (isnumeric(v) || islogical(v)) && isscalar(v) && isreal(v);
    isTextScalar = @(v) (ischar(v) && (isrow(v) || isempty(v))) || (isstring(v) && isscalar(v));

    if all(cellfun(isNumScalar, pv))
        col = nan(n, 1);
        col(present) = cellfun(@double, pv);
    elseif all(cellfun(isTextScalar, pv))
        col = strings(n, 1);
        col(:) = missing;
        col(present) = string(cellfun(@char, pv, 'UniformOutput', false));
    else
        col = cell(n, 1);
        col(present) = pv;
    end
end
