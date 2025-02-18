# Toledo S/MIME Certificate Manager 🔐

A Bash script for automating S/MIME certificate management using OpenSSL. Designed for Toledo Systems PKI needs, this tool simplifies Root CA creation, user certificate issuance, and certificate validation.

## Features ✨
- Initialize PKI directory structure
- Generate RSA-4096 Root CA certificates (valid 10 years)
- Issue user certificates with PKCS#12 (.p12) export
- Email address validation with regex
- Built-in logging and permissions hardening
- OpenSSL configuration autogeneration

## Prerequisites 📋
- OpenSSL 1.1.1+ (TLS 1.3 compatible)
- Bash 4.2+
- Basic CLI knowledge
- Secure directory for CA storage (recommended: air-gapped system)

## Installation ⚙️
```bash
git clone https://github.com/toledo-labs/smime_manager.git
cd smime_manager
cp config.example.env config.env  # Edit with your details
chmod +x smime_manager.sh
```
## Configuration
- Edit config.env with your organizational details:
```bash
# Organization Details
COMPANY_NAME="CyberSecure Solutions Inc."
COMPANY_DOMAIN="cybersecuresolutions.io"
COUNTRY="CA"                # ISO 2-letter country code
STATE="QC"                  # State/Province code
CITY="Montreal"
ORG_UNIT="Digital Security"

# CA Configuration
CA_EMAIL="pki-admin@cybersecuresolutions.io"
CA_DIR="${HOME}/CyberSecure/CS-PKI/company_ca"
CERT_VALIDITY_DAYS=360      # 1 year for user certificates
ROOT_CA_VALIDITY_DAYS=3650  # 10 years for Root CA
```
## Usage 🖥️
- Initialize CA Structure
```bash
./smime_manager.sh init
```
- Creates directory structure:
```bash
~/ToledoSystems/TS-PKI/company_ca
├── private/    # 700 permissions
├── certs/      # Root + user certs
├── newcerts/   # Issued certificates
└── index.txt   # Certificate database
```
## Generate Root CA
```bash
./smime_manager.sh create-root-ca
```
- Outputs:
    - private/root_CA.key (RSA-4096, chmod 400)
    - certs/root_CA.crt (X.509 certificate)
## Issue User Certificate
```bash
./smime_manager.sh create-user-cert john.doe@cybersecuresolutions.io
```
- Generates:
    - private/john.doe.key (RSA-2048)
    - certs/john.doe.crt (Signed by Root CA)
    - certs/john.doe.p12 (PKCS#12 bundle for email clients)


