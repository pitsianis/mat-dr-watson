function s = serializeValue(v)
% SERIALIZEVALUE Unambiguous text form of a parameter value, used to build cache keys.
%   Two values get the same text only if they have the same class, the same
%   size, and the same contents. So Inf and NaN, int8(1) and 1, 'x' and "x",
%   and row and column vectors all get different cache keys. Struct fields
%   are sorted, so field order does not matter.
%
%   Supported: numeric and logical arrays (including complex and sparse),
%   char, string, cell, and struct (nested arbitrarily). Anything else
%   (function handles, datetime, categorical, tables, objects) raises an
%   error, because there is no reliable way to tell two such values apart.

    sz = sprintf('%dx', size(v));
    head = [class(v) '[' sz(1:end-1) ']'];

    if isnumeric(v) || islogical(v)
        if issparse(v)
            v = full(v);
            head = ['sparse_' head];
        end
        if isreal(v)
            s = [head '(' numText(v) ')'];
        else
            s = [head 'complex(' numText(real(v)) ';' numText(imag(v)) ')'];
        end

    elseif ischar(v)
        s = sprintf('%s%d:%s', head, numel(v), v(:)');  % length prefix keeps it unambiguous

    elseif isstring(v)
        parts = strings(1, numel(v));
        for i = 1:numel(v)
            if ismissing(v(i))
                parts(i) = "<missing>";
            else
                parts(i) = strlength(v(i)) + ":" + v(i);
            end
        end
        s = [head '(' char(strjoin(parts, ',')) ')'];

    elseif iscell(v)
        parts = cellfun(@serializeValue, v(:)', 'UniformOutput', false);
        s = [head '{' strjoin(parts, ',') '}'];

    elseif isstruct(v)
        fields = sort(fieldnames(v))';
        elems = cell(1, numel(v));
        for k = 1:numel(v)
            fieldParts = cell(1, numel(fields));
            for j = 1:numel(fields)
                fieldParts{j} = [fields{j} '=' serializeValue(v(k).(fields{j}))];
            end
            elems{k} = ['<' strjoin(fieldParts, ';') '>'];
        end
        s = [head '{' strjoin(fields, ',') '}' strjoin(elems, ',')];

    else
        error('produceOrLoad:UnsupportedParamType', ...
            ['Parameters of class "%s" are not supported. Use numbers, logicals, ' ...
             'text, cells, or structs instead (for example, store a datetime as ' ...
             'text, or a function choice as its name: params.method = "rk4").'], class(v));
    end
end

function t = numText(v)
    v = v(:)';
    if isempty(v)
        t = '';
    elseif isa(v, 'double')
        t = sprintf('%.17g,', v);   % 17 significant digits round-trip every double exactly
    elseif isa(v, 'single')
        t = sprintf('%.9g,', v);    % 9 significant digits round-trip every single exactly
    elseif islogical(v)
        t = sprintf('%d,', uint8(v));
    elseif startsWith(class(v), 'uint')
        t = sprintf('%u,', v);
    else
        t = sprintf('%d,', v);
    end
end
