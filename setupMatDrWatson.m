function setupMatDrWatson(options)
% SETUPMATDRWATSON Adds the MatDrWatson toolbox folder to the MATLAB path.
%
%   setupMatDrWatson              % for this MATLAB session only
%   setupMatDrWatson(Save=true)   % also for future sessions (runs savepath)
%
%   Alternative: install MatDrWatson.mltbx (built by buildToolbox), which
%   adds the toolbox to the path permanently through the Add-On Manager.
%
%   Only the toolbox folder is added. The examples and tests folders stay
%   off the path, so their files never shadow your own functions.

    arguments
        options.Save (1,1) logical = false
    end

    toolboxDir = fullfile(fileparts(mfilename('fullpath')), 'toolbox');
    addpath(toolboxDir);
    fprintf('Added to the MATLAB path: %s\n', toolboxDir);

    if options.Save
        if savepath() == 0
            fprintf('Saved the path for future MATLAB sessions.\n');
        else
            warning('setupMatDrWatson:SavepathFailed', ...
                ['Could not save the path (no write permission for pathdef.m). ' ...
                 'Add "addpath(''%s'')" to your startup.m instead.'], toolboxDir);
        end
    end
end
