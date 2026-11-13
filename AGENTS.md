# Notes for coding agents

MatDrWatson is a MATLAB toolbox for running parameter sweeps, caching each run's result keyed by its parameters and code, and collecting results into a table, in the style of Julia's DrWatson.jl. User documentation is in `README.md`; every public function has detailed `help` text.

## Layout

- `toolbox/`: the only folder on the MATLAB path. Public functions: `dictList`, `produceOrLoad`, `collectResults`, `manageCache`, and `MatDrWatson` (overview). `Contents.m` holds the version. `private/` holds the hashing and dependency-check helpers.
- `examples/`: demo (`example_sweep.m`, `simulateDecay.m`, `computePhysicsStep.m`) and `experiment_manager/ExperimentFunctionTemplate.m`. Never put this folder on the path: its files would collide with users' own files.
- `tests/`: `runAllTests.m`, four test groups, and `fixtures/`.
- `setupMatDrWatson.m` (adds `toolbox/` to the path) and `buildToolbox.m` (builds the `.mltbx`).

## Commands

Run from the repository root:

- Tests: `matlab -batch "addpath tests; runAllTests"`. Takes about a minute; runs in a temporary copy, so it never modifies the repository. Success ends with `All 4 test groups passed.`
- Build: `matlab -batch "buildToolbox"` writes `release/MatDrWatson.mltbx` (git-ignored).

## Helping someone use the toolbox

- The experiment function must be a named function in its own `.m` file that takes one params struct and returns the result. Anonymous and nested functions are rejected, because captured values would not be part of the cache key.
- Parameter values may be numbers, logicals, text, cells, and structs. `'x'` (char) and `"x"` (string) are different cache keys; Experiment Manager passes strings.
- `dictList` sweeps over vector elements. Wrap an array in a cell (`{[1 2 3]}`) to use it as one value; unwrapped matrices raise an error.
- Data files the experiment reads must be listed in `ExtraFiles`, or edits to them go unnoticed.
- Analyze results with `collectResults(cacheDir, OnlyCurrent=true)`. Clean stale runs with `manageCache(cacheDir, 'clean')`.
- Install the `.mltbx` with a full path. `matlab.addons.install("~/...")` fails with "Argument must be a text scalar."

## Rules when changing the toolbox

- Run the tests before committing. For every bug fix, add a test and check that it fails without the fix.
- Do not change the hash output for existing inputs (`serializeValue`, `hashFileList`, `sha256String`, `sha256File`): it would silently orphan every user's cache. If a change is unavoidable, increase `meta.keyVersion` in `produceOrLoad` and the check in `private/codeStatus.m`, so old files show as `OLD_FORMAT`.
- Keep the `rehash` call in `produceOrLoad` before the experiment runs. Without it, parallel workers run stale code after an edit and save wrong results as current.
- The version appears in three places: `toolbox/Contents.m`, `toolbox/MatDrWatson.m`, and the default in `buildToolbox.m`.
- Release: bump the version, run the tests, commit, push, run `buildToolbox`, then `gh release create vX.Y.Z release/MatDrWatson.mltbx`. The README links to `releases/latest`, so no README change is needed.
