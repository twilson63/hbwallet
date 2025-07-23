Name:           hbwallet
Version:        1.0.0
Release:        1%{?dist}
Summary:        Arweave JWK wallet generator

License:        MIT
URL:            https://github.com/yourusername/hbwallet
Source0:        https://github.com/yourusername/hbwallet/releases/download/v%{version}/hbwallet-%{version}-linux-amd64.tar.gz

BuildArch:      x86_64
Requires:       lua >= 5.1

%description
hbwallet is a command-line tool for generating JWK (JSON Web Key)
wallets compatible with Arweave blockchain. It creates RSA keypairs
and extracts 43-character wallet addresses.

%prep
%setup -q -c

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}
install -m 755 hbwallet $RPM_BUILD_ROOT%{_bindir}/hbwallet

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{_bindir}/hbwallet

%changelog
* Mon Jan 01 2024 Your Name <your.email@example.com> - 1.0.0-1
- Initial release of hbwallet