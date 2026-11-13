function testKeysAndInputs(root)
% TESTKEYSANDINPUTS Cache keys, input validation, old-format files, local functions, parfor.
%   Called by runAllTests with root = the temporary copy of the project.

    c = fullfile(root, 'cache_keys');

    % Values that used to share a cache key must now get separate files;
    % the same struct with fields in a different order must share one.
    pairs = { Inf, NaN; int8(1), 1; 'x', "x"; [1 2], [1; 2]; ...
              intmax('uint64'), intmax('uint64') - 1; 1+2i, 1-2i; sparse(1), 1; ...
              {}, []; string(missing), "<missing>"; true, 1; single(1), 1; ...
              {'a,b'}, {'a', 'b'}; struct('a', {1, 2}), struct('a', {2, 1}) };
    for k = 1:size(pairs, 1)
        [~, m1] = produceOrLoad(@echoParams, struct('v', {pairs(k, 1)}), c, Verbose=false);
        [~, m2] = produceOrLoad(@echoParams, struct('v', {pairs(k, 2)}), c, Verbose=false);
        assert(~strcmp(m1.cacheFile, m2.cacheFile), 'Pair %d shares a cache file', k);
    end
    a.x = 1; a.y = {struct('p', 1, 'q', 2)};
    b.y = {struct('q', 2, 'p', 1)}; b.x = 1;
    [~, m1] = produceOrLoad(@echoParams, a, c, Verbose=false);
    [~, m2] = produceOrLoad(@echoParams, b, c, Verbose=false);
    assert(strcmp(m1.cacheFile, m2.cacheFile) && m2.fromCache, 'Field order changed the cache key');
    pass(sprintf('%d formerly colliding value pairs get separate cache files; field order is ignored', size(pairs, 1)));

    expectError(@() produceOrLoad(@echoParams, struct('f', @sin), c), 'produceOrLoad:UnsupportedParamType');
    expectError(@() produceOrLoad(@echoParams, struct('d', datetime('now')), c), 'produceOrLoad:UnsupportedParamType');
    expectError(@() produceOrLoad(@(p) echoParams(p), struct('a', 1), c), 'produceOrLoad:UnsupportedFunction');
    expectError(@() produceOrLoad(@echoParams, struct('a', 1), c, ExtraFiles="no_such_file.csv"), ...
        'produceOrLoad:MissingExtraFile');
    pass('unsupported parameter types, anonymous functions, and missing ExtraFiles raise clear errors');

    expectError(@() dictList(struct('A', eye(3))), 'dictList:MatrixField');
    expectError(@() dictList(struct('A', {{1 2; 3 4}})), 'dictList:MatrixField');
    assert(numel(dictList(struct('A', {{eye(3)}}))) == 1, 'A wrapped matrix should be one value');
    assert(numel(dictList(struct('w', {{[1 2 3]}}, 'm', ["a" "b"]))) == 2, 'Wrapped vector or string sweep is wrong');
    assert(numel(dictList(struct('s', struct('k', 1), 'e', [], 'name', 'euler'))) == 1, ...
        'Scalar struct, empty, or char field was split');
    pass('dictList rejects matrices and accepts {} wrapping, strings, structs, empties, and char');

    % A file written by the previous version has no meta.keyVersion.
    [result, meta] = produceOrLoad(@echoParams, struct('v', 1), c, Verbose=false); %#ok<ASGLU>
    meta = rmfield(meta, 'keyVersion');
    oldFile = fullfile(c, 'echoParams_oldformat.mat');
    save(oldFile, 'result', 'meta');
    t = manageCache(c);
    assert(t.Status(t.FileName == "echoParams_oldformat.mat") == "OLD_FORMAT", 'Old file not reported as OLD_FORMAT');
    nCurrent = sum(t.Status == "CURRENT");
    assert(height(collectResults(c, OnlyCurrent=true, Verbose=false)) == nCurrent, 'OnlyCurrent kept the old file');
    manageCache(c, 'clean');
    assert(~isfile(oldFile), 'clean did not remove the OLD_FORMAT file');
    pass('old-format files are reported, skipped by OnlyCurrent, and removed by clean');

    [~, m] = produceOrLoad(@echoParams, struct('v', [Inf NaN]), c, Verbose=false);
    t = manageCache(c);
    [~, name, ext] = fileparts(m.cacheFile);
    shown = t.ParamsJSON(t.FileName == string([name ext]));
    assert(contains(shown, "Inf") && contains(shown, "NaN"), 'ParamsJSON shows: %s', shown);
    pass('manageCache shows Inf and NaN, not null');

    m = localFnFile(c);
    deps = string(m.dependencies);
    assert(any(endsWith(deps, "computePhysicsStep.m")) && any(endsWith(deps, "localFnFile.m")), ...
        'Local function dependencies not tracked');
    pass('a local function works, and its file and helpers are tracked');

    if ~canUseParallelPool()
        fprintf('  SKIP: parfor test (no Parallel Computing Toolbox)\n');
        return;
    end
    g = dictList(struct('x0', 1, 'T', 1, 'dt', 0.1, 'alpha', [1 2 3 4]));
    fromCache = false(1, numel(g));
    parfor i = 1:numel(g)
        [~, mm] = produceOrLoad(@runExperiment, g(i), c, Verbose=false);
        fromCache(i) = mm.fromCache;
    end
    assert(~any(fromCache), 'First parfor sweep should compute every run');
    parfor i = 1:numel(g)
        [~, mm] = produceOrLoad(@runExperiment, g(i), c, Verbose=false);
        fromCache(i) = mm.fromCache;
    end
    assert(all(fromCache), 'Second parfor sweep should load every run from the cache');
    pass('parfor: the first sweep computes, the second loads from the cache');
end

function pass(msg)
    fprintf('  PASS: %s\n', msg);
end

function expectError(f, id)
    try
        f();
    catch err
        assert(strcmp(err.identifier, id), 'Expected error %s, got %s: %s', id, err.identifier, err.message);
        return;
    end
    error('testKeysAndInputs:NoError', 'Expected error %s, but no error was raised', id);
end
