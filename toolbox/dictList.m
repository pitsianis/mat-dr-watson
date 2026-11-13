function paramList = dictList(specStruct)
% DICTLIST Expands a struct of parameter vectors/cells into a struct array of all combinations.
%   Replicates DrWatson.jl's dict_list functionality in MATLAB.
%
%   paramList = dictList(specStruct)
%
%   Input:
%       specStruct - Scalar struct where each field is either:
%                    * A numeric/logical/string vector: each element is one value to sweep
%                    * A cell vector of arbitrary items: each cell is one value to sweep
%                    * A char array: treated as a single value, not split by character
%                    * A scalar or empty value: used as-is in every combination
%
%   To use a whole vector or matrix as ONE parameter value, wrap it in a cell:
%       spec.weights = {[0.2 0.3 0.5]};      % one value, not three
%       spec.A       = {eye(3), ones(3)};    % two values to sweep
%   A matrix that is not wrapped raises an error, because sweeping over its
%   elements is almost never what was meant.
%
%   Output:
%       paramList  - 1xN struct array covering the full Cartesian product of inputs.
%                    The first field varies fastest.
%
%   Example:
%       spec.alpha = [0.1, 0.5, 1.0];
%       spec.dt    = [0.01, 0.005];
%       spec.mode  = {'euler', 'rk4'};
%       grid = dictList(spec); % Returns 1x12 struct array

    arguments
        specStruct (1,1) struct
    end

    fields = fieldnames(specStruct);
    nFields = numel(fields);

    if nFields == 0
        paramList = struct();
        return;
    end

    % Normalize every field into a 1D cell array of candidate values
    valueCells = cell(1, nFields);
    for i = 1:nFields
        val = specStruct.(fields{i});
        if ischar(val) || isempty(val)
            valueCells{i} = {val};
        elseif ~isvector(val)
            error('dictList:MatrixField', ...
                ['Field "%s" is a %s %s array. dictList sweeps over the elements of vectors only. ' ...
                 'To use the whole array as one parameter value, wrap it in a cell: spec.%s = {value}. ' ...
                 'To sweep over several arrays, list them in a cell: spec.%s = {A1, A2}.'], ...
                fields{i}, strjoin(string(size(val)), 'x'), class(val), fields{i}, fields{i});
        elseif iscell(val)
            valueCells{i} = val(:)';
        else
            valueCells{i} = num2cell(val(:)');
        end
    end

    % Build Cartesian product index grid
    sizes = cellfun(@numel, valueCells);
    ranges = arrayfun(@(n) 1:n, sizes, 'UniformOutput', false);
    gridIdx = cell(1, nFields);
    if nFields == 1
        gridIdx{1} = ranges{1}(:);
    else
        [gridIdx{:}] = ndgrid(ranges{:});
    end

    totalCombos = prod(sizes);
    paramList = repmat(struct(), 1, totalCombos);

    for k = 1:totalCombos
        for f = 1:nFields
            idx = gridIdx{f}(k);
            paramList(k).(fields{f}) = valueCells{f}{idx};
        end
    end
end
