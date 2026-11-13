# MATLAB Reproducible Simulation Kit (`dictList` + `produceOrLoad` + `collectResults` + `manageCache`)

A lightweight MATLAB toolkit replicating the core workflow of Julia's **[DrWatson.jl](https://github.com/JuliaDynamics/DrWatson.jl)**, using only base MATLAB and without requiring Git. The Parallel Computing Toolbox is optional.

## Installation

1. Download **[MatDrWatson.mltbx](https://github.com/pitsianis/mat-dr-watson/releases/latest/download/MatDrWatson.mltbx)** from the [latest release](https://github.com/pitsianis/mat-dr-watson/releases/latest).
2. In MATLAB, double-click the file in the Current Folder browser, or run one of the following lines (with the full path to the downloaded file):
   ```matlab
   matlab.addons.install(fullfile(getenv("HOME"), "Downloads", "MatDrWatson.mltbx"))         % macOS, Linux
   ```
   ```matlab
   matlab.addons.install(fullfile(getenv("USERPROFILE"), "Downloads", "MatDrWatson.mltbx"))  % Windows
   ```
   Don't write the path as `"~/Downloads/..."`: `matlab.addons.install` fails on `~` with the misleading error "Argument must be a text scalar."

That's all you need: the toolbox goes on the MATLAB path permanently, and the examples, the Experiment Manager template, and this README come with it. To upgrade, install a newer `.mltbx` the same way. To uninstall, use the Add-On Manager (**Home ▸ Add-Ons ▸ Manage Add-Ons**).


### Check the installation

Run `which produceOrLoad`. It should print a path ending in `toolbox/produceOrLoad.m`.

Then work from your own project folder, anywhere on disk: keep your experiment functions there and pass a cache folder such as `'cache_data'`, which is created relative to the current folder.

---

## Getting Started

### Getting help

```matlab
help MatDrWatson        % overview of the toolbox
help produceOrLoad      % details of one function (also dictList, collectResults, manageCache)
```

### Looking at and running the demo

The examples folder sits next to the installed toolbox, but is not on the path. These lines find it with either installation method, from any current folder:

```matlab
exampleDir = fullfile(fileparts(fileparts(which("produceOrLoad"))), "examples");
edit(fullfile(exampleDir, "example_sweep.m"))   % the demo script
edit(fullfile(exampleDir, "simulateDecay.m"))   % the experiment it runs
run(fullfile(exampleDir, "example_sweep.m"))    % run the demo
```

The demo writes its results to `examples/demo_cache`. It starts with `clear`, so it empties your workspace.

To change the examples or use them as a starting point, copy them to your own folder first, because edits to the installed copy are lost when you upgrade the toolbox:

```matlab
copyfile(exampleDir, "my_examples")
```

---

## How to Use It

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
    [res, meta] = produceOrLoad(@simulateDecay, paramGrid(i), 'cache_data');
end
```
* **First run:** Executes `simulateDecay` and saves `simulateDecay_<hash>.mat`.
* **Subsequent runs:** Loads instantly from disk if parameters and all helper `.m` files are unchanged.
* **After editing code:** The edit is detected automatically on the next call (also on parallel workers) and the affected runs are recomputed.
* **Parallel execution:** Safe inside `parfor` and `parfeval` because saves use atomic temp-file renames.
* **Your function** must be a named function that takes the params struct as its only input and returns the result. Put it in its own file: a local function also works, but then its whole file counts as code, so editing anything in that file (say, the plotting part of your sweep script) makes every run stale. Anonymous functions such as `@(p) simulateDecay(p, K)` are rejected, because a change to `K` would not be noticed. Put every setting into `params` instead.
* **Parameter values** may be numbers, logicals, text, cells, and structs, nested as deep as you like. Every difference counts: `Inf` vs `NaN`, `int8(1)` vs `1`, `'x'` vs `"x"`, and row vs column vectors all give separate runs. Function handles, `datetime`, `categorical`, and other objects raise an error; store them as text instead (e.g. `params.method = "rk4"`).

### 3. Collect Results into a Table (`collectResults`)
```matlab
tbl = collectResults('cache_data');                      % every run in the folder
tbl = collectResults('cache_data', FuncHandle=@simulateDecay, OnlyCurrent=true);

scatter(tbl.alpha, tbl.finalValue)                       % parameters and results are columns
```
* One row per run, sorted by parameter values. When the same parameters were run more than once (for example before and after a code edit), the current run comes first, then the older ones, newest first.
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
manageCache('cache_data', 'clean', FuncHandle=@simulateDecay);
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

## Using Experiment Manager (optional)

MATLAB's [Experiment Manager](https://www.mathworks.com/help/matlab/ref/experimentmanager-app.html) app (included in MATLAB R2023b and newer) lets you define the parameter grid in a table, run the trials one at a time or in parallel, and browse the results, all without writing a loop. Combined with `produceOrLoad`, rerunning an experiment only recomputes the trials whose parameters or code changed; all others load instantly from disk.

Experiment Manager replaces `dictList` and the loop. `produceOrLoad` does the saving and reloading, and `collectResults` and `manageCache` work on the saved runs as usual.

### Setting it up with the example

1. Make sure the toolbox is installed (`which produceOrLoad` prints a path).
2. Open the app with `experimentManager`, click **Blank Project**, choose the **General Purpose** template, and pick a folder and name for the project.
3. Copy `examples/simulateDecay.m` and `examples/computePhysicsStep.m` into the project folder. For your own work, copy your experiment function and its helpers instead.
4. In the experiment's **Parameters** table, add:

   | Name | Values |
   |---|---|
   | `x0` | `10` |
   | `T` | `1` |
   | `dt` | `0.01` |
   | `alpha` | `[0.5 1 2 4]` |
   | `tag` | `["baseline" "control"]` |

5. Open the experiment function that Experiment Manager created (for example `Experiment1Function1.m`). Replace its contents with those of `examples/experiment_manager/ExperimentFunctionTemplate.m`, but keep the function name Experiment Manager gave it in the first line.
6. Click **Run**. The results table shows `finalValue` and `fromCache` for each of the 8 trials.
7. Click **Run** again: every trial shows `fromCache` = true and finishes almost instantly. Now change `damping = 1.0;` in the project's copy of `computePhysicsStep.m` and run once more: every trial is recomputed.
8. To analyze the runs outside the app, use `collectResults(fullfile(currentProject().RootFolder, "cache_data"))`.

To use your own experiment function, replace `@simulateDecay` in the template, and change the outputs (`finalValue` in the example) to the result fields you want as columns in the results table.

### Things to know

* **Parallel trials:** parallel workers may not have the project loaded, so the template's default cache folder (`<project root>/cache_data`) fails there with an error that says so. Before running in parallel, set `cacheDir` near the top of the experiment function to an absolute path, such as `"/Users/me/my_project/cache_data"`.
* **Text parameters:** Experiment Manager passes text as strings (`"baseline"`), while `spec.tag = {'baseline'}` in `dictList` passes chars (`'baseline'`), and the two get different cache keys. To share saved runs between scripts and Experiment Manager, use string arrays in scripts too: `spec.tag = ["baseline" "control"]`.
* **Snapshots:** Experiment Manager runs each result from a frozen copy of your project files (in `Results/.../Snapshot/`). `produceOrLoad` records your project's own files instead, so editing them marks old runs as stale. Runs saved by version 0.2.3 or earlier recorded the snapshot copies and always show `CURRENT`: delete `cache_data` and rerun the experiment to fix that.
* **Two copies of the outputs:** Experiment Manager keeps the values the experiment function returns in its own results, inside the project. The complete results of every run are in `cache_data`.
* **Initialization functions:** if the experiment has an initialization function, Experiment Manager adds its output to `params` as `InitializationFunctionOutput`. The template removes that field before calling `produceOrLoad`, so it isn't part of the cache key and isn't passed to your experiment function.

---

## Requirements and Limitations

* **MATLAB version:** R2021a or newer (the `Name=Value` call syntax). Tested on R2026a.
* **Parallel Computing Toolbox:** optional. Without it, use a plain `for` loop; the demo switches to one automatically.
* **A failing run stops the sweep.** To keep going and retry failures later, wrap the call:
  ```matlab
  for i = 1:numel(paramGrid)
      try
          produceOrLoad(@simulateDecay, paramGrid(i), 'cache_data');
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

## Relation to DrWatson.jl

[DrWatson.jl](https://github.com/JuliaDynamics/DrWatson.jl) ([documentation](https://juliadynamics.github.io/DrWatson.jl/stable/)) is a Julia package for managing scientific projects: parameter sweeps, saving and reloading simulation results, and collecting them for analysis. This toolkit brings its core workflow to MATLAB users who don't use Julia:

| DrWatson.jl | This toolkit |
|---|---|
| `dict_list` | `dictList` |
| `produce_or_load` | `produceOrLoad` |
| `collect_results` | `collectResults` |
| (no direct equivalent) | `manageCache`: check saved runs against the current code and delete stale ones |

Differences:
- **Code changes are detected automatically.** Results are keyed by the parameters *and* a hash of the code they depend on, so editing your code reruns the affected experiments. DrWatson instead can record the Git commit with each result, and reloads a saved result whenever its file exists.
- **Not included:** project scaffolding (`initialize_project`, `datadir`, `plotsdir`), readable file names (`savename`), and Git tagging (`tagsave`).
- This is an independent MATLAB project, not affiliated with DrWatson.jl or its authors.
