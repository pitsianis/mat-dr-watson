function [finalValue, fromCache] = ExperimentFunctionTemplate(params)
% EXPERIMENTFUNCTIONTEMPLATE Experiment Manager function that reuses saved runs.
%
%   Experiment Manager (MATLAB R2023b or newer) defines the parameter grid,
%   runs the trials, and shows the results table. This function hands each
%   trial to produceOrLoad, so trials whose parameters and code are
%   unchanged load instantly from disk instead of running again.
%
%   How to use it (details in the README, section "Using Experiment Manager"):
%     1. Copy the body of this function into the experiment function that
%        Experiment Manager creates for you (for example Experiment1Function1.m).
%     2. Replace @simulateDecay with your own experiment function.
%     3. Return the result fields you want to see as columns in the results
%        table, and name them in the function's first line.
%
%   The outputs are shown as columns in Experiment Manager's results table:
%       finalValue - an example result field
%       fromCache  - true if the trial was loaded from disk, false if it ran

    % Folder where saved runs go. Leave empty to use <project root>/cache_data.
    % For parallel trials, set an absolute path instead, for example
    %   cacheDir = "/Users/me/my_project/cache_data";
    % because parallel workers may not have the project loaded.
    cacheDir = "";

    if cacheDir == ""
        try
            cacheDir = fullfile(currentProject().RootFolder, "cache_data");
        catch
            error("ExperimentFunctionTemplate:NoProject", ...
                "No MATLAB project is loaded here (this happens on parallel workers). " + ...
                "Set cacheDir near the top of the experiment function to an absolute path.");
        end
    end

    % Experiment Manager adds this field when the experiment has an
    % initialization function. It is not a parameter, so it must not be part
    % of the cache key.
    if isfield(params, "InitializationFunctionOutput")
        params = rmfield(params, "InitializationFunctionOutput");
    end

    [result, meta] = produceOrLoad(@simulateDecay, params, cacheDir, Verbose=false);

    finalValue = result.finalValue;
    fromCache = meta.fromCache;
end
