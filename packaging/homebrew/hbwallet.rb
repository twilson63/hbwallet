class Hbwallet < Formula
  desc "Arweave JWK wallet generator"
  homepage "https://github.com/yourusername/hbwallet"
  version "1.0.0"
  
  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/yourusername/hbwallet/releases/download/v1.0.0/hbwallet-1.0.0-darwin-arm64.tar.gz"
      sha256 "PLACEHOLDER_SHA256_DARWIN_ARM64"
    else
      url "https://github.com/yourusername/hbwallet/releases/download/v1.0.0/hbwallet-1.0.0-darwin-amd64.tar.gz"
      sha256 "PLACEHOLDER_SHA256_DARWIN_AMD64"
    end
  end
  
  on_linux do
    if Hardware::CPU.arm?
      if Hardware::CPU.is_64_bit?
        url "https://github.com/yourusername/hbwallet/releases/download/v1.0.0/hbwallet-1.0.0-linux-arm64.tar.gz"
        sha256 "PLACEHOLDER_SHA256_LINUX_ARM64"
      else
        url "https://github.com/yourusername/hbwallet/releases/download/v1.0.0/hbwallet-1.0.0-linux-arm.tar.gz"
        sha256 "PLACEHOLDER_SHA256_LINUX_ARM"
      end
    else
      url "https://github.com/yourusername/hbwallet/releases/download/v1.0.0/hbwallet-1.0.0-linux-amd64.tar.gz"
      sha256 "PLACEHOLDER_SHA256_LINUX_AMD64"
    end
  end

  def install
    bin.install "hbwallet"
  end

  test do
    # Test wallet generation
    output = shell_output("#{bin}/hbwallet")
    assert_match /"kty":\s*"RSA"/, output
    assert_match /"n":/, output
    assert_match /"e":\s*"AQAB"/, output
    
    # Test address extraction
    wallet_file = testpath/"test_wallet.json"
    wallet_file.write(output)
    
    address = shell_output("#{bin}/hbwallet public-key --file #{wallet_file}").strip
    assert_equal 43, address.length
    assert_match /^[A-Za-z0-9_-]+$/, address
  end
end