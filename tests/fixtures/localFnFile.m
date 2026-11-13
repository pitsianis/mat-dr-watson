function meta = localFnFile(cacheDir)
% Test fixture: runs produceOrLoad on a local function defined in this file.
    [~, meta] = produceOrLoad(@localSim, struct('a', 1), cacheDir, Verbose=false);
end

function out = localSim(p)
    out.v = computePhysicsStep(1, p.a, 0.1);
end
