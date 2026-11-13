function h = sha256String(str)
% SHA256STRING Lowercase hex SHA-256 digest of a char/string value.
    md = java.security.MessageDigest.getInstance('SHA-256');
    bytes = md.digest(uint8(char(str)));
    h = lower(reshape(dec2hex(typecast(bytes, 'uint8'))', 1, []));
end
