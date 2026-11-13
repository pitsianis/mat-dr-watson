function MatDrWatson()
% MATDRWATSON DrWatson.jl-style experiment management for MATLAB.
%   Version 0.2.3
%
%   Parameter grids
%     dictList       - Expand a struct of parameter values into all combinations.
%
%   Running experiments
%     produceOrLoad  - Run an experiment, or load its saved result if the
%                      parameters and code are unchanged.
%
%   Results
%     collectResults - Gather all saved runs into one table for analysis.
%     manageCache    - List saved runs, check them against the current code,
%                      and delete stale ones.
%
%   Type "help <name>" for details on each function, e.g. help produceOrLoad.
%
%   Demo (the examples folder is next to the toolbox folder, not on the path):
%     exampleDir = fullfile(fileparts(fileparts(which("produceOrLoad"))), "examples");
%     edit(fullfile(exampleDir, "example_sweep.m"))   % read the demo script
%     run(fullfile(exampleDir, "example_sweep.m"))    % run it
%
%   Typing MatDrWatson on its own shows this overview and the examples folder.
%
%   Documentation: https://github.com/pitsianis/mat-dr-watson#readme

    help MatDrWatson
    exampleDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'examples');
    if isfolder(exampleDir)
        fprintf('  Examples folder: %s\n\n', exampleDir);
    end
end
