%% Example Workflow: dictList + produceOrLoad + parfeval + manageCache + collectResults
% Runs with or without the Parallel Computing Toolbox. Needs the toolbox
% folder on the path (run setupMatDrWatson, or install the .mltbx).
% Run it from anywhere with:  run(fullfile(<repo>, 'examples', 'example_sweep.m'))
clear; clc;

if exist('produceOrLoad', 'file') ~= 2
    error('example_sweep:ToolboxNotFound', ...
        'MatDrWatson is not on the MATLAB path. Run setupMatDrWatson from the repository folder first.');
end

% Everything this demo writes stays next to this script, wherever MATLAB's
% current folder is. cd'ing here also makes runExperiment.m and
% computePhysicsStep.m visible (they are deliberately not on the path).
exampleDir = fileparts(mfilename('fullpath'));
cd(exampleDir);
cacheFolder = fullfile(exampleDir, 'demo_cache');
if isfolder(cacheFolder)
    rmdir(cacheFolder, 's');
end

%% 1. Generate Cartesian Parameter Grid using dictList
spec.x0    = [10.0];
spec.T     = [1.0];
spec.dt    = [0.01];
spec.alpha = [0.5, 1.0, 2.0];
spec.tag   = {'baseline', 'control'};

paramGrid = dictList(spec);
fprintf('Generated %d parameter combinations via dictList.\n\n', numel(paramGrid));

%% 2. Run Initial Parameter Sweep (Cache Misses)
fprintf('--- STEP 1: Initial Sweep (All Cache Misses) ---\n');
results = cell(1, numel(paramGrid));
for i = 1:numel(paramGrid)
    results{i} = produceOrLoad(@runExperiment, paramGrid(i), cacheFolder);
end

%% 3. Re-run Sweep (All Cache Hits)
fprintf('\n--- STEP 2: Re-running Identical Sweep (All Cache Hits) ---\n');
for i = 1:numel(paramGrid)
    results{i} = produceOrLoad(@runExperiment, paramGrid(i), cacheFolder);
end

%% 4. Sweep Again, in Parallel if Possible (Adding new alpha = 4.0)
usePool = canUseParallelPool(); % false without the Parallel Computing Toolbox
if usePool
    fprintf('\n--- STEP 3: Parallel Sweep via parfeval (Mixed Hits & Misses) ---\n');
else
    fprintf('\n--- STEP 3: Sweep in a Plain Loop (no parallel pool available) ---\n');
end
spec.alpha = [0.5, 1.0, 2.0, 4.0];
expandedGrid = dictList(spec);

metas = runSweep(expandedGrid, cacheFolder, usePool);
fprintf('Completed %d tasks (%d loaded from cache).\n', numel(metas), sum([metas.fromCache]));

%% 5. Inspect Cache with manageCache
fprintf('\n--- STEP 4: Inspecting Cache Table ---\n');
tbl = manageCache(cacheFolder, 'list');
disp(tbl(:, {'FileName', 'Status', 'RunTimeSec', 'SizeKB'}));

%% 6. Collect All Results into One Table with collectResults
fprintf('\n--- STEP 5: Collecting Results into a Table ---\n');
resultsTbl = collectResults(cacheFolder);
disp(resultsTbl(:, {'alpha', 'tag', 'finalValue', 'Status'}));

%% 7. Simulate Downstream Code Edit -> Stale Detection & Cleanup
fprintf('\n--- STEP 6: Editing computePhysicsStep.m & Cleaning Stale Runs ---\n');
helperFile = fullfile(exampleDir, 'computePhysicsStep.m');
origCode = fileread(helperFile);

% The edit is undone below, also if a step fails. (If you stop the script
% with Ctrl+C here, check that computePhysicsStep.m says damping = 1.0.)
try
    % Modify damping factor inside helper function
    writeTextFile(helperFile, strrep(origCode, 'damping = 1.0;', 'damping = 1.25;'));
    % No `clear produceOrLoad` needed: edits are detected automatically,
    % including on the parallel workers.

    % Check status before cleaning
    tblAfterEdit = manageCache(cacheFolder, 'list');
    disp(tblAfterEdit(:, {'FileName', 'Status'}));

    % Clean stale entries automatically
    manageCache(cacheFolder, 'clean');

    %% 8. Re-run the Sweep with the Edited Code (All Cache Misses)
    fprintf('\n--- STEP 7: Re-running the Sweep After the Edit ---\n');
    metas = runSweep(expandedGrid, cacheFolder, usePool);
    fprintf('Completed %d tasks (%d loaded from cache).\n', numel(metas), sum([metas.fromCache]));
    newTbl = collectResults(cacheFolder, OnlyCurrent=true);
    disp(newTbl(:, {'alpha', 'tag', 'finalValue', 'Status'}));
catch err
    writeTextFile(helperFile, origCode);
    rethrow(err);
end
writeTextFile(helperFile, origCode);
fprintf('Restored the original computePhysicsStep.m.\n');

function metas = runSweep(grid, cacheFolder, usePool)
% Run produceOrLoad for every parameter set, on a parallel pool if available.
    if usePool
        futures(numel(grid)) = parallel.FevalFuture;
        for i = 1:numel(grid)
            futures(i) = parfeval(@produceOrLoad, 2, @runExperiment, grid(i), cacheFolder);
        end
        [~, metas] = fetchOutputs(futures);
    else
        for i = 1:numel(grid)
            [~, metas(i)] = produceOrLoad(@runExperiment, grid(i), cacheFolder); %#ok<AGROW>
        end
    end
end

function writeTextFile(path, txt)
    fid = fopen(path, 'w');
    fwrite(fid, txt, 'char');
    fclose(fid);
end
