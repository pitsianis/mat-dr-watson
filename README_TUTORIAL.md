# MATLAB Reproducible Simulation Kit (`dictList` + `produceOrLoad` + `collectResults` + `manageCache`)

A lightweight MATLAB toolkit replicating the core workflow of Julia's **DrWatson.jl**, using only base MATLAB and without requiring Git. The Parallel Computing Toolbox is optional.

## Folder Layout

```
mat-dr-watson/
├── toolbox/                The toolbox itself: the only folder that goes on the MATLAB path
│   ├── dictList.m          Parameter grid: all combinations (DrWatson's dict_list)
│   ├── produceOrLoad.m     Run an experiment or load its saved result (DrWatson's produce_or_load)
│   ├── collectResults.m    All saved runs in one table (DrWatson's collect_results)
│   ├── manageCache.m       List saved runs, check them against current code, clean stale ones
│   ├── Contents.m          Toolbox overview and version
│   └── private/            Internal helpers (hashing, dependency checks); never called directly
├── examples/               Runnable demo (not on the path)
│   ├── example_sweep.m     The demo script
│   ├── runExperiment.m     Example experiment function
│   └── computePhysicsStep.m  Helper it calls (edited by the demo to show change detection)
├── tests/                  Automated tests (see "Running the Tests")
├── setupMatDrWatson.m      Puts toolbox/ on the path
└── buildToolbox.m          Builds release/MatDrWatson.mltbx for distribution
```

The examples and tests stay off the path on purpose: if they were on it, the example's `runExperiment.m` could shadow, or be shadowed by, a student's own file of the same name.

---

## Installation

Pick one:

* **Install the `.mltbx` (recommended for students).** Double-click `MatDrWatson.mltbx` in MATLAB, or run `matlab.addons.install("MatDrWatson.mltbx")`. This puts the toolbox on the path permanently, and the Add-On Manager can uninstall or upgrade it. To build the file, run `buildToolbox` in the repository folder (needs MATLAB R2023a or newer); it writes `release/MatDrWatson.mltbx`.
* **Use the repository folder directly.** From the repository folder run:
  ```matlab
  setupMatDrWatson              % for this MATLAB session
  setupMatDrWatson(Save=true)   % also for future sessions
  ```

Check the installation with `which produceOrLoad`, which should print a path ending in `toolbox/produceOrLoad.m`.

Then work from your own project folder, anywhere on disk: keep your experiment functions there and pass a cache folder such as `'cache_data'`, which is created relative to the current folder.

### Running the Demo

```matlab
run(fullfile(fileparts(fileparts(which("produceOrLoad"))), "examples", "example_sweep.m"))
```
This finds the examples folder next to the installed toolbox, so it works with either installation method and from any current folder. The demo writes its results to `examples/demo_cache`. It starts with `clear`, so it empties your workspace.

---

## Quick Start

### 1. Generate a Parameter Grid (`dictList`)
```matlab
spec.alpha = [0.5, 1.0, 2.0];
spec.dt    = [0.01, 0.005];
spec.mode  = {'euler', 'rk4'};

paramGrid = dictList(spec); % Returns a 1x12 struct array
```
* **Vectors are swept:** each element of a numeric, logical, or string vector, and each cell of a cell vector, is one value.
* **Text is one value:** a char array such as `'euler'` is never split into characters.
* **Arrays as one value:** to use a whole vector or matrix as a single parameter, wrap it in a cell:
  ```matlab
  spec.weights = {[0.2 0.3 0.5]};     % one value, not three
  spec.A       = {eye(3), ones(3)};   % two matrices to sweep over
  ```
  An unwrapped matrix (`spec.A = eye(3)`) raises an error instead of silently sweeping over its 9 elements.

### 2. Run & Cache Simulations (`produceOrLoad`)
```matlab
for i = 1:numel(paramGrid)
    [res, meta] = produceOrLoad(@runExperiment, paramGrid(i), 'cache_data');
end
```
* **First run:** Executes `runExperiment` and saves `runExperiment_<hash>.mat`.
* **Subsequent runs:** Loads instantly from disk if parameters and all helper `.m` files are unchanged.
* **After editing code:** The edit is detected automatically on the next call (also on parallel workers) and the affected runs are recomputed.
* **Parallel execution:** Safe inside `parfor` and `parfeval` because saves use atomic temp-file renames.
* **Your function** must be a named function that takes the params struct as its only input and returns the result. Put it in its own file: a local function also works, but then its whole file counts as code, so editing anything in that file (say, the plotting part of your sweep script) makes every run stale. Anonymous functions such as `@(p) runExperiment(p, K)` are rejected, because a change to `K` would not be noticed. Put every setting into `params` instead.
* **Parameter values** may be numbers, logicals, text, cells, and structs, nested as deep as you like. Every difference counts: `Inf` vs `NaN`, `int8(1)` vs `1`, `'x'` vs `"x"`, and row vs column vectors all give separate runs. Function handles, `datetime`, `categorical`, and other objects raise an error; store them as text instead (e.g. `params.method = "rk4"`).

### 3. Collect Results into a Table (`collectResults`)
```matlab
tbl = collectResults('cache_data');                      % every run in the folder
tbl = collectResults('cache_data', FuncHandle=@runExperiment, OnlyCurrent=true);

scatter(tbl.alpha, tbl.finalValue)                       % parameters and results are columns
```
* One row per run, sorted by parameter values.
* Scalar numbers and text become normal columns; vectors, matrices, and structs become cell columns (e.g. `tbl.trace{1}`).
* Nested structs are flattened: `params.solver.tol` becomes column `solver_tol`.
* `OnlyCurrent=true` skips runs produced by older versions of your code.

### 4. Inspect & Clean Stale Caches (`manageCache`)
```matlab
% View all cached simulations and whether their code dependencies are still current
tbl = manageCache('cache_data', 'list');

% Preview stale files whose code dependencies have changed
manageCache('cache_data', 'clean', DryRun=true);

% Delete stale files
manageCache('cache_data', 'clean');

% Only list/clean runs of one function (others in the same folder are left alone)
manageCache('cache_data', 'clean', FuncHandle=@runExperiment);
```

Each run remembers the files it depended on, so `manageCache` and `collectResults` check every run against its own dependencies, including `ExtraFiles`. Status values:

| Status | Meaning | Deleted by `'clean'`? |
|---|---|---|
| `CURRENT` | All dependencies unchanged | No |
| `STALE_CODE` | A dependency changed since the run | Yes |
| `MISSING_DEPS` | A dependency no longer exists (e.g. project folder moved) | No |
| `UNKNOWN_CODE_STATE` | Run has no dependency information | No |
| `OLD_FORMAT` | Made by an older version of this toolkit; rerunning the sweep creates a new file, so this one is a leftover | Yes |
| `INVALID` | File could not be read | Yes, unless `FuncHandle` is given |

---

## Requirements and Limitations

* **MATLAB version:** R2021a or newer (the `Name=Value` call syntax). Tested on R2026a.
* **Parallel Computing Toolbox:** optional. Without it, use a plain `for` loop; the demo switches to one automatically.
* **A failing run stops the sweep.** To keep going and retry failures later, wrap the call:
  ```matlab
  for i = 1:numel(paramGrid)
      try
          produceOrLoad(@runExperiment, paramGrid(i), 'cache_data');
      catch err
          fprintf('Run %d failed: %s\n', i, err.message);
      end
  end
  ```
  A failed run saves nothing, so the next sweep tries it again.
* **Data files your code reads:** `matlab.codetools.requiredFilesAndProducts` finds `.m` files your code calls by name. It does not track data files, and it may miss functions called through text (`feval`, `str2func`). If your simulation reads `.csv`/`.mat` files, or calls functions that way, pass those files via `ExtraFiles=["data/input.csv"]`. Relative paths are resolved from the current folder at the time of the call.
* **Moving the project folder:** dependency paths are stored as absolute paths, so after a move, existing runs show `MISSING_DEPS`. They are kept, not deleted. Rerunning the sweep loads them from the cache (no recomputation, since the code is unchanged) and updates their stored paths, after which they show `CURRENT` again.
* **Memory:** `collectResults` loads every result in the folder. If each run returns large arrays, use `FuncHandle` to collect one function at a time, or have your function return only summary values.
* **Demo:** `example_sweep.m` temporarily edits `computePhysicsStep.m` and restores it at the end, also if a step fails. If you stop it with Ctrl+C during steps 6–7, check that the file says `damping = 1.0;`.

---

## Running the Tests

From the repository folder:
```matlab
addpath tests
runAllTests
```
The tests run in a temporary copy of the toolbox and examples, so your files and cache folders are never touched, and the toolbox does not need to be installed. They check code-change detection, `manageCache`, `collectResults`, cache keys, input validation, `parfor`, and the demo, and end with `All 3 test groups passed.` The `parfor` test is skipped without the Parallel Computing Toolbox. Run them after changing any toolkit file.
