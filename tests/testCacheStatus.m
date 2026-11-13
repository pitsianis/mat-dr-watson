function testCacheStatus(root)
% TESTCACHESTATUS Code-change detection, manageCache, and collectResults.
%   Called by runAllTests with root = the temporary copy of the project.

    c = fullfile(root, 'cache_status');
    simParams = @(alpha) struct('x0', 1, 'T', 1, 'dt', 0.1, 'alpha', alpha);
    g = dictList(struct('alpha', [1 2]));
    for i = 1:2
        produceOrLoad(@runExperiment, simParams(g(i).alpha), c, Verbose=false);
        produceOrLoad(@runOther, g(i), c, Verbose=false);
        produceOrLoad(@runWithData, g(i), c, ExtraFiles="data/scale.txt", Verbose=false);
    end
    t = manageCache(c);
    assert(height(t) == 6 && all(t.Status == "CURRENT"), 'Expected 6 CURRENT runs, got: %s', strjoin(t.Status, ', '));
    pass('6 runs of 3 functions, all CURRENT (including an ExtraFiles run)');

    oldDir = cd(tempdir);
    backToRoot = onCleanup(@() cd(oldDir));
    t = manageCache(c);
    clear backToRoot
    assert(all(t.Status == "CURRENT"), 'Status changed when checked from another folder');
    pass('status is correct when checked from another folder');

    % Edit a helper used only by runExperiment, without `clear produceOrLoad`.
    helper = fullfile(root, 'computePhysicsStep.m');
    dataFile = fullfile(root, 'data', 'scale.txt');
    origHelper = fileread(helper);
    origData = fileread(dataFile);
    restoreFiles = onCleanup(@() cellfun(@writeFile, {helper, dataFile}, {origHelper, origData})); %#ok<NASGU>
    writeFile(helper, strrep(origHelper, 'damping = 1.0;', 'damping = 1.5;'));
    [~, m] = produceOrLoad(@runExperiment, simParams(1), c, Verbose=false);
    assert(~m.fromCache, 'Edit to computePhysicsStep.m was not detected');
    pass('code edit detected without `clear produceOrLoad`');

    t = manageCache(c, 'list', FuncHandle=@runOther);
    assert(height(t) == 2 && all(t.Function == "runOther"), 'FuncHandle did not filter the listing');
    pass('FuncHandle filters the listing');

    manageCache(c, 'clean', FuncHandle=@runOther);
    t = manageCache(c);
    assert(height(t) == 7 && sum(t.Status == "STALE_CODE") == 2, ...
        'clean with FuncHandle=@runOther touched other functions'' runs');
    pass('clean(FuncHandle=@runOther) leaves other functions'' runs alone');

    manageCache(c, 'clean');
    t = manageCache(c);
    assert(height(t) == 5 && all(t.Status == "CURRENT"), 'clean did not remove exactly the 2 stale runs');
    pass('clean removes only the stale runs');

    writeFile(dataFile, '4.0');
    t = manageCache(c, 'list', FuncHandle=@runWithData);
    assert(all(t.Status == "STALE_CODE"), 'Change to an ExtraFiles file was not detected');
    pass('a change to an ExtraFiles file marks its runs STALE_CODE');

    r = collectResults(c, FuncHandle=@runWithData, Verbose=false);
    assert(isequal(r.alpha, [1; 2]), 'Rows not sorted by parameter value');
    assert(all(r.result_alpha == -1) && all(r.result_Status == "mine") && all(r.Status == "STALE_CODE"), ...
        'Result fields clashing with parameter/bookkeeping names were not renamed');
    pass('collectResults sorts rows and renames clashing result fields');

    assert(height(collectResults(c, OnlyCurrent=true, Verbose=false)) == 3, 'OnlyCurrent did not skip stale runs');
    pass('collectResults(OnlyCurrent=true) skips stale runs');

    r = collectResults(c, FuncHandle=@runOther, Verbose=false);
    assert(isequal(r.result, [2; 4]), 'Non-struct result column is wrong');
    pass('a non-struct result becomes a "result" column');
end

function pass(msg)
    fprintf('  PASS: %s\n', msg);
end

function writeFile(p, txt)
    fid = fopen(p, 'w');
    fwrite(fid, txt, 'char');
    fclose(fid);
end
