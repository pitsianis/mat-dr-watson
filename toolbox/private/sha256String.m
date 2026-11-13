function h = sha256String(str)
% SHA256STRING Lowercase hex SHA-256 digest of a char/string value.
    md = java.security.MessageDigest.getInstance('SHA-256');
    data = uint8(char(str));
    if ~isempty(data)   % MATLAB passes an empty array to Java as null
        md.update(data);
    end
    bytes = md.digest();
    h = lower(reshape(dec2hex(typecast(bytes, 'uint8'))', 1, []));
end
