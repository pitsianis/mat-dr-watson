function h = sha256File(filepath)
% SHA256FILE Lowercase hex SHA-256 digest of a file's raw bytes.
    fid = fopen(filepath, 'rb');
    if fid < 0
        error('matDrWatson:FileOpenError', 'Cannot open file: %s', filepath);
    end
    cleanup = onCleanup(@() fclose(fid));
    rawBytes = fread(fid, Inf, '*uint8');
    md = java.security.MessageDigest.getInstance('SHA-256');
    if ~isempty(rawBytes)   % MATLAB passes an empty array to Java as null
        md.update(rawBytes);
    end
    bytes = md.digest();
    h = lower(reshape(dec2hex(typecast(bytes, 'uint8'))', 1, []));
end
