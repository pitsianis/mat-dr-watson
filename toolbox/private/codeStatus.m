function status = codeStatus(meta, memo)
% CODESTATUS Checks a cached run's recorded dependencies against the files on disk.
%   Uses the dependency list stored in the run's own meta, so it works for
%   any function and includes ExtraFiles.
%
%   Returns one of:
%     "CURRENT"            - every recorded dependency is unchanged
%     "STALE_CODE"         - at least one recorded dependency changed
%     "MISSING_DEPS"       - a recorded dependency no longer exists (e.g. the
%                            project folder was moved); never auto-deleted
%     "UNKNOWN_CODE_STATE" - the file has no dependency information
%     "OLD_FORMAT"         - produced by an older version of produceOrLoad whose
%                            cache keys are no longer used; rerunning the sweep
%                            creates new files, so this one is a leftover
    if ~isfield(meta, 'keyVersion') || meta.keyVersion < 2
        status = "OLD_FORMAT";
        return;
    end
    if ~isfield(meta, 'dependencies') || ~isfield(meta, 'codeHash')
        status = "UNKNOWN_CODE_STATE";
        return;
    end
    deps = string(meta.dependencies);
    if any(~isfile(deps))
        status = "MISSING_DEPS";
    elseif hashFileList(deps, memo) == string(meta.codeHash)
        status = "CURRENT";
    else
        status = "STALE_CODE";
    end
end
