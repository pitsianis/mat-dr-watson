function dx = computePhysicsStep(x, alpha, dt)
% COMPUTEPHYSICSSTEP Downstream helper function tracked automatically by produceOrLoad.
    damping = 1.0;
    dx = (-alpha * damping * x) * dt;
end
