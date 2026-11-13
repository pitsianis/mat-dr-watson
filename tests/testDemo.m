function testDemo(root)
% TESTDEMO Runs example_sweep.m end to end and checks its output.
%   Called by runAllTests with root = the temporary copy of the project.

    helper = fullfile(root, 'computePhysicsStep.m');
    out = runDemo();

    assert(contains(out, 'Completed 8 tasks (6 loaded from cache)'), 'Step 3 did not reuse the 6 cached runs');
    assert(contains(out, 'Completed 8 tasks (0 loaded from cache)'), 'Step 7 did not recompute after the code edit');
    assert(contains(out, 'Deleted 8 file(s) during "clean"'), 'Step 6 did not clean the 8 stale runs');
    assert(contains(out, 'Restored the original computePhysicsStep.m'), 'Demo did not report restoring the helper');
    assert(contains(fileread(helper), 'damping = 1.0;'), 'computePhysicsStep.m was not restored');
    if canUseParallelPool()
        mode = 'parallel';
    else
        mode = 'plain loop';
    end
    pass(sprintf('example_sweep.m runs end to end (%s) and restores computePhysicsStep.m', mode));

    overview = evalc('MatDrWatson');
    assert(all(contains(overview, ["produceOrLoad", "dictList", "collectResults", "manageCache"])), ...
        'MatDrWatson overview does not list the four functions');
    assert(contains(evalc('help MatDrWatson'), 'example_sweep.m'), 'help MatDrWatson does not show how to open the demo');
    pass('MatDrWatson and help MatDrWatson show the overview and the demo commands');
end

function out = runDemo()
% The demo starts with `clear`, so run it in a workspace of its own.
    out = evalc('example_sweep');
end

function pass(msg)
    fprintf('  PASS: %s\n', msg);
end
