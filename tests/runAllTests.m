function runAllTests()
% RUNALLTESTS Runs the toolkit's tests in a temporary copy of the project.
%
%   From the project folder:
%       addpath tests
%       runAllTests
%
%   Nothing in your project folder is changed: toolbox/ is copied to a
%   temporary folder, examples/ and tests/fixtures/ are copied next to it,
%   the tests run there with the copied toolbox first on the path (ahead of
%   any installed MatDrWatson), and the folder is deleted afterwards.
%   The tests do not need the toolbox to be installed. Tests that need a parallel
%   pool are skipped when the Parallel Computing Toolbox is not available.
%   Takes about a minute, mostly for starting the parallel pool.

    testsDir = fileparts(mfilename('fullpath'));
    projectDir = fileparts(testsDir);

    sandbox = tempname;
    mkdir(sandbox);
    copyfile(fullfile(projectDir, 'toolbox'), fullfile(sandbox, 'toolbox'));
    exampleFiles = dir(fullfile(projectDir, 'examples', '*.m'));
    for i = 1:numel(exampleFiles)
        copyfile(fullfile(exampleFiles(i).folder, exampleFiles(i).name), sandbox);
    end
    copyfile(fullfile(testsDir, 'fixtures'), sandbox);

    oldDir = pwd;
    oldPath = path;
    cleanup = onCleanup(@() restore(oldDir, oldPath, sandbox)); %#ok<NASGU>
    addpath(testsDir);
    addpath(fullfile(sandbox, 'toolbox'), '-begin');
    cd(sandbox);
    setPoolFolder(sandbox);

    tests = {@testCacheStatus, @testKeysAndInputs, @testDemo};
    failed = strings(1, 0);
    for k = 1:numel(tests)
        name = func2str(tests{k});
        fprintf('\n=== %s\n', name);
        cd(sandbox);   % in case a failed test left another folder current
        try
            tests{k}(sandbox);
        catch err
            fprintf(2, '  FAIL: %s\n', err.message);
            failed(end+1) = name; %#ok<AGROW>
        end
    end

    fprintf('\n');
    if isempty(failed)
        fprintf('All %d test groups passed.\n', numel(tests));
    else
        error('runAllTests:Failed', '%d of %d test groups failed: %s', ...
            numel(failed), numel(tests), strjoin(failed, ', '));
    end
end

function setPoolFolder(folder)
% Point the workers of an already-running pool at the same folder as the
% client, so they run the sandbox copies of the toolkit. (A pool started
% later starts in the client's current folder anyway.)
    if canUseParallelPool()
        p = gcp('nocreate');
        if ~isempty(p)
            wait(parfevalOnAll(p, @cd, 0, folder));
        end
    end
end

function restore(oldDir, oldPath, sandbox)
    cd(oldDir);
    setPoolFolder(oldDir);
    path(oldPath);
    if isfolder(sandbox)
        rmdir(sandbox, 's');
    end
end
