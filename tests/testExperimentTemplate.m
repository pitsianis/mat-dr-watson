function testExperimentTemplate(root)
% TESTEXPERIMENTTEMPLATE Calls the Experiment Manager template the way the app does.
%   Creates a temporary MATLAB project, copies the template and the example
%   functions into it, and calls the template with a params struct like the
%   one Experiment Manager passes (text values as strings). The Experiment
%   Manager app itself is not driven by this test.
%   Called by runAllTests with root = the temporary copy of the project.

    checkSnapshotPaths(root);

    if ~isempty(matlab.project.rootProject)
        % Creating a project would close the one you have open.
        fprintf('  SKIP: a MATLAB project is open; close it to run this test\n');
        return;
    end

    projDir = fullfile(root, 'em_project');
    mkdir(projDir);
    proj = matlab.project.createProject(projDir);
    closeProject = onCleanup(@() proj.close()); %#ok<NASGU>
    copyfile(fullfile(root, 'simulateDecay.m'), projDir);
    copyfile(fullfile(root, 'computePhysicsStep.m'), projDir);
    copyfile(fullfile(root, 'experiment_manager', 'ExperimentFunctionTemplate.m'), projDir);
    oldDir = cd(projDir);
    backToRoot = onCleanup(@() cd(oldDir)); %#ok<NASGU>

    p = struct('x0', 10, 'T', 1, 'dt', 0.01, 'alpha', 0.5, 'tag', "baseline");
    [v1, c1] = ExperimentFunctionTemplate(p);
    [v2, c2] = ExperimentFunctionTemplate(p);
    assert(~c1 && c2 && v1 == v2, 'Expected a computed trial, then the same value from the cache');
    pass('first trial computes, the repeated trial loads from the cache');

    p.InitializationFunctionOutput = containers.Map();
    [~, c3] = ExperimentFunctionTemplate(p);
    assert(c3, 'InitializationFunctionOutput changed the cache key');
    pass('the InitializationFunctionOutput field is left out of the cache key');

    t = collectResults(fullfile(projDir, 'cache_data'), Verbose=false);
    assert(height(t) == 1 && t.tag == "baseline" && t.Status == "CURRENT", ...
        'Saved run not found in <project root>/cache_data');
    pass('runs are saved in <project root>/cache_data and readable by collectResults');

    proj.close();
    cd(projDir);   % closing a project can change the current folder
    try
        ExperimentFunctionTemplate(p);
        error('testExperimentTemplate:NoError', 'Expected an error without a loaded project');
    catch err
        assert(strcmp(err.identifier, 'ExperimentFunctionTemplate:NoProject'), ...
            'Expected ExperimentFunctionTemplate:NoProject, got %s', err.identifier);
    end
    pass('without a loaded project (as on parallel workers) it explains how to set cacheDir');
end

function checkSnapshotPaths(root)
% Experiment Manager runs each result from a frozen copy of the project
% files in <project>/Results/<result>/Snapshot/. Simulate that layout.
    proj = fullfile(root, 'snapshot_project');
    snap1 = fullfile(proj, 'Results', 'Experiment1_Result1_20260101T000000', 'Snapshot');
    snap2 = fullfile(proj, 'Results', 'Experiment1_Result2_20260101T000100', 'Snapshot');
    for folder = {proj, snap1, snap2}
        mkdir(folder{1});
        copyfile(fullfile(root, 'simulateDecay.m'), folder{1});
        copyfile(fullfile(root, 'computePhysicsStep.m'), folder{1});
    end
    c = fullfile(proj, 'cache_data');
    p = struct('x0', 10, 'T', 1, 'dt', 0.01, 'alpha', 0.5, 'tag', "baseline");
    oldDir = pwd;
    backToRoot = onCleanup(@() cd(oldDir)); %#ok<NASGU>

    cd(snap1);   % like Experiment Manager running Result1
    [~, m] = produceOrLoad(@simulateDecay, p, c, Verbose=false);
    deps = string(m.dependencies);
    assert(~m.fromCache && ~any(contains(deps, "Snapshot")) && all(startsWith(deps, proj)), ...
        'Snapshot paths were recorded instead of the project files');
    t = manageCache(c);
    assert(t.Status == "CURRENT", 'Expected CURRENT, got %s', t.Status);
    pass('runs from an Experiment Manager snapshot record the project''s own files');

    cachedFile = fullfile(c, t.FileName);
    before = dir(cachedFile).datenum;
    pause(1.1);
    cd(snap2);   % like Experiment Manager running Result2 with unchanged code
    [~, m] = produceOrLoad(@simulateDecay, p, c, Verbose=false);
    assert(m.fromCache, 'Unchanged code in a new snapshot should be a cache hit');
    assert(dir(cachedFile).datenum == before, 'A cache hit from a new snapshot rewrote the cache file');
    pass('a cache hit from a new snapshot leaves the cache file untouched');

    helper = fullfile(proj, 'computePhysicsStep.m');
    fid = fopen(helper, 'w');
    fwrite(fid, strrep(fileread(fullfile(snap1, 'computePhysicsStep.m')), 'damping = 1.0;', 'damping = 1.25;'), 'char');
    fclose(fid);
    t = manageCache(c);
    assert(t.Status == "STALE_CODE", 'Editing the project file should make the run STALE_CODE, got %s', t.Status);
    pass('editing the project''s file (not the snapshot) marks the run STALE_CODE');
end

function pass(msg)
    fprintf('  PASS: %s\n', msg);
end
