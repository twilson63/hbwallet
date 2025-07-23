-- OpenSSL-based crypto implementation for proper RSA key generation
local ffi = require("ffi")
local bit = require("bit")

-- Load OpenSSL library
local ssl = ffi.load("ssl")
local crypto = ffi.load("crypto")

-- FFI definitions for OpenSSL
ffi.cdef[[
    // Basic types
    typedef struct bignum_st BIGNUM;
    typedef struct rsa_st RSA;
    typedef struct evp_pkey_st EVP_PKEY;
    typedef struct evp_pkey_ctx_st EVP_PKEY_CTX;
    
    // BIGNUM functions
    BIGNUM *BN_new(void);
    void BN_free(BIGNUM *a);
    int BN_set_word(BIGNUM *a, unsigned long w);
    int BN_bn2bin(const BIGNUM *a, unsigned char *to);
    int BN_num_bytes(const BIGNUM *a);
    
    // RSA functions
    RSA *RSA_new(void);
    void RSA_free(RSA *r);
    int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, void *cb);
    
    // RSA structure access (OpenSSL 1.1.0+)
    void RSA_get0_key(const RSA *r, const BIGNUM **n, const BIGNUM **e, const BIGNUM **d);
    void RSA_get0_factors(const RSA *r, const BIGNUM **p, const BIGNUM **q);
    void RSA_get0_crt_params(const RSA *r, const BIGNUM **dmp1, const BIGNUM **dmq1, const BIGNUM **iqmp);
    
    // EVP functions
    EVP_PKEY *EVP_PKEY_new(void);
    void EVP_PKEY_free(EVP_PKEY *pkey);
    int EVP_PKEY_assign_RSA(EVP_PKEY *pkey, RSA *key);
    
    // Random number generation
    int RAND_bytes(unsigned char *buf, int num);
    
    // SHA256
    unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md);
]]

-- Helper to convert BIGNUM to base64url
local function bn_to_base64url(bn)
    if bn == nil then return nil end
    
    local len = crypto.BN_num_bytes(bn)
    local buf = ffi.new("unsigned char[?]", len)
    crypto.BN_bn2bin(bn, buf)
    
    -- Convert to Lua string
    local str = ffi.string(buf, len)
    
    -- Base64URL encode
    local b64 = require("mime").b64(str)
    return b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

-- Generate RSA keypair
local function generate_rsa_keypair(bits)
    bits = bits or 4096
    
    -- Create RSA structure
    local rsa = crypto.RSA_new()
    if rsa == nil then
        error("Failed to create RSA structure")
    end
    
    -- Set public exponent (65537)
    local e = crypto.BN_new()
    crypto.BN_set_word(e, 65537)
    
    -- Generate key
    local ret = crypto.RSA_generate_key_ex(rsa, bits, e, nil)
    if ret ~= 1 then
        crypto.BN_free(e)
        crypto.RSA_free(rsa)
        error("Failed to generate RSA key")
    end
    
    -- Extract key components
    local n_ptr = ffi.new("const BIGNUM*[1]")
    local e_ptr = ffi.new("const BIGNUM*[1]")
    local d_ptr = ffi.new("const BIGNUM*[1]")
    local p_ptr = ffi.new("const BIGNUM*[1]")
    local q_ptr = ffi.new("const BIGNUM*[1]")
    local dp_ptr = ffi.new("const BIGNUM*[1]")
    local dq_ptr = ffi.new("const BIGNUM*[1]")
    local qi_ptr = ffi.new("const BIGNUM*[1]")
    
    crypto.RSA_get0_key(rsa, n_ptr, e_ptr, d_ptr)
    crypto.RSA_get0_factors(rsa, p_ptr, q_ptr)
    crypto.RSA_get0_crt_params(rsa, dp_ptr, dq_ptr, qi_ptr)
    
    -- Convert to base64url
    local jwk = {
        n = bn_to_base64url(n_ptr[0]),
        e = bn_to_base64url(e_ptr[0]),
        d = bn_to_base64url(d_ptr[0]),
        p = bn_to_base64url(p_ptr[0]),
        q = bn_to_base64url(q_ptr[0]),
        dp = bn_to_base64url(dp_ptr[0]),
        dq = bn_to_base64url(dq_ptr[0]),
        qi = bn_to_base64url(qi_ptr[0])
    }
    
    -- Cleanup
    crypto.BN_free(e)
    crypto.RSA_free(rsa)
    
    return jwk
end

-- SHA256 hash
local function sha256(data)
    local md = ffi.new("unsigned char[32]")
    crypto.SHA256(data, #data, md)
    return ffi.string(md, 32)
end

return {
    generate_rsa_keypair = generate_rsa_keypair,
    sha256 = sha256
}