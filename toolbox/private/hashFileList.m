function codeHash = hashFileList(files, memo)
% HASHFILELIST Combined SHA-256 hash of a list of files.
%   This is the single definition of the "code hash" shared by produceOrLoad,
%   manageCache, and collectResults, so they can never disagree.
%
%   memo (optional) - containers.Map from file path to file hash, reused
%                     across calls so each file is read at most once.
    files = sort(string(files(:)));
    files = files(files ~= "");
    fileHashes = strings(numel(files), 1);
    for i = 1:numel(files)
        key = char(files(i));
        if nargin > 1 && isKey(memo, key)
            fileHashes(i) = memo(key);
            continue;
        end
        if isfile(files(i))
            fileHashes(i) = string(sha256File(files(i)));
        else
            fileHashes(i) = "MISSING_FILE";
        end
        if nargin > 1
            memo(key) = fileHashes(i);
        end
    end
    codeHash = sha256String(char(strjoin(fileHashes, ':')));
end
