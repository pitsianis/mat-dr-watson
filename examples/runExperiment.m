function out = runExperiment(params)
% RUNEXPERIMENT Sample simulation calling computePhysicsStep.
    x = params.x0;
    nSteps = round(params.T / params.dt);
    trace = zeros(1, nSteps + 1);
    trace(1) = x;

    for k = 1:nSteps
        x = x + computePhysicsStep(x, params.alpha, params.dt);
        trace(k + 1) = x;
    end

    out.finalValue = x;
    out.trace = trace;
    out.paramsUsed = params;
end
