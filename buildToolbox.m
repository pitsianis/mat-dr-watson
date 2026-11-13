function mltbxFile = buildToolbox(version)
% BUILDTOOLBOX Packages MatDrWatson as an installable .mltbx file.
%
%   buildToolbox            % version 0.2.1
%   buildToolbox("0.3.0")   % set the version
%
%   Writes release/MatDrWatson.mltbx. Students install it by double-clicking
%   it in MATLAB (or with matlab.addons.install), which puts the toolbox
%   folder on their path permanently. The examples folder and the README are
%   included but not put on the path. Tests are not included.
%
%   Requires MATLAB R2023a or newer to build. The toolbox itself runs on
%   R2021a or newer.

    arguments
        version (1,1) string = "0.2.1"
    end

    root = fileparts(mfilename('fullpath'));
    % Fixed identifier: keep it unchanged so new versions upgrade old installs.
    opts = matlab.addons.toolbox.ToolboxOptions(root, "472db285-67ba-45df-88e3-1aa35db7b134");
    opts.ToolboxName = "MatDrWatson";
    opts.ToolboxVersion = version;
    opts.Summary = "DrWatson.jl-style parameter sweeps, result caching, and result collection for MATLAB.";
    opts.Description = ...
        "Run many experiments over a grid of parameters, save each result keyed by its " + ...
        "parameters and code, skip runs that are already done, and gather everything " + ...
        "into one table. Detects code changes automatically and works with parfor/parfeval.";
    opts.MinimumMatlabRelease = "R2021a";
    % List the example's .m files explicitly, so a demo_cache folder left
    % over from running the demo is not packaged.
    exampleFiles = dir(fullfile(root, "examples", "**", "*.m"));
    opts.ToolboxFiles = [fullfile(root, "toolbox"), ...
                         string(fullfile({exampleFiles.folder}, {exampleFiles.name})), ...
                         fullfile(root, "README.md")];
    opts.ToolboxMatlabPath = fullfile(root, "toolbox");

    outDir = fullfile(root, "release");
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    opts.OutputFile = fullfile(outDir, "MatDrWatson.mltbx");

    matlab.addons.toolbox.packageToolbox(opts);
    mltbxFile = opts.OutputFile;
    fprintf('Built %s (version %s)\n', mltbxFile, version);
end
