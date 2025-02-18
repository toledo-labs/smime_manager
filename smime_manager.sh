#!/bin/bash

set -euo pipefail
source ./config.env

# Logging configuration
readonly LOGFILE="${CA_DIR}/ca.log"
readonly DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

# Create log function that creates directory and file if they don't exist
setup_logging() {
    # Create CA directory if it doesn't exist
    mkdir -p "${CA_DIR}"
    # Create log file if it doesn't exist
    touch "${LOGFILE}"
    # Set appropriate permissions
    chmod 600 "${LOGFILE}"
}

# Functions for logging
log_info() {
    echo "${DATETIME} [INFO] $1" | tee -a "${LOGFILE}"
}

log_error() {
    echo "${DATETIME} [ERROR] $1" | tee -a "${LOGFILE}"
    exit 1
}

# Function to validate email address
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_error "Invalid email format: $email"
    fi
}

# Initialize CA directory structure
init_ca() {
    # Setup logging first
    setup_logging
    
    log_info "Initializing CA directory structure"
    
    mkdir -p "${CA_DIR}"/{private,certs,newcerts,crl}
    chmod 700 "${CA_DIR}/private"
    touch "${CA_DIR}/index.txt"
    echo "1000" > "${CA_DIR}/serial"
    
    # Generate OpenSSL config
    create_openssl_config
    
    log_info "CA directory structure initialized"
}

# Create OpenSSL configuration
create_openssl_config() {
    cat > "${CA_DIR}/openssl.cnf" << EOF
# OpenSSL configuration
[ca]
default_ca = company_ca

[company_ca]
dir               = ${CA_DIR}
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

private_key       = \$dir/private/root_CA.key
certificate       = \$dir/certs/root_CA.crt

default_days      = ${CERT_VALIDITY_DAYS}
default_md        = sha256
preserve          = no
policy            = policy_strict

[policy_strict]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress           = supplied

[req]
default_bits        = 2048
default_keyfile     = privkey.pem
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
string_mask         = utf8only

[req_distinguished_name]
countryName                     = Country Name (2 letter code)
stateOrProvinceName            = State or Province Name
localityName                   = Locality Name
organizationName               = Organization Name
organizationalUnitName         = Organizational Unit Name
commonName                     = Common Name
emailAddress                   = Email Address

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[smime]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = emailProtection
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always, issuer
subjectAltName = email:copy
EOF
}

# Generate Root CA
create_root_ca() {
    log_info "Generating Root CA"
    
    if [ -f "${CA_DIR}/private/root_CA.key" ]; then
        log_error "Root CA already exists"
    fi
    
    openssl req -x509 -sha256 -days "${ROOT_CA_VALIDITY_DAYS}" -nodes \
        -newkey rsa:4096 \
        -subj "/CN=${COMPANY_NAME} ROOT CA/OU=${ORG_UNIT}/O=${COMPANY_NAME}/C=${COUNTRY}/ST=${STATE}/L=${CITY}/emailAddress=${CA_EMAIL}" \
        -keyout "${CA_DIR}/private/root_CA.key" \
        -out "${CA_DIR}/certs/root_CA.crt" \
        -extensions v3_ca
    
    chmod 400 "${CA_DIR}/private/root_CA.key"
    log_info "Root CA generated successfully"
}

# Generate user certificate
create_user_cert() {
    local email="$1"
    local username="${email%@*}"
    
    log_info "Generating certificate for $email"
    validate_email "$email"
    
    # Generate unique serial number
    local serial=$(openssl rand -hex 16)
    
    # Generate user key and CSR
    openssl req -new -newkey rsa:2048 -nodes \
        -subj "/CN=${COMPANY_DOMAIN}/OU=${ORG_UNIT}/O=${COMPANY_NAME}/emailAddress=${email}" \
        -keyout "${CA_DIR}/private/${username}.key" \
        -out "${CA_DIR}/certs/${username}.csr"
    
    # Sign CSR with Root CA (corrected version)
    openssl x509 -req \
        -days "${CERT_VALIDITY_DAYS}" \
        -in "${CA_DIR}/certs/${username}.csr" \
        -CA "${CA_DIR}/certs/root_CA.crt" \
        -CAkey "${CA_DIR}/private/root_CA.key" \
        -CAcreateserial \
        -out "${CA_DIR}/certs/${username}.crt" \
        -extfile "${CA_DIR}/openssl.cnf" \
        -extensions smime
    
    # Set appropriate permissions
    chmod 400 "${CA_DIR}/private/${username}.key"
    chmod 444 "${CA_DIR}/certs/${username}.crt"
    
    # Create PKCS#12 file
    openssl pkcs12 -export \
        -in "${CA_DIR}/certs/${username}.crt" \
        -inkey "${CA_DIR}/private/${username}.key" \
        -out "${CA_DIR}/certs/${username}.p12" \
        -name "${username} Email Certificate"
    
    log_info "Certificate generated for $email"
    
    # Display certificate information
    log_info "Certificate details:"
    openssl x509 -in "${CA_DIR}/certs/${username}.crt" -text -noout
}

# Verify certificate
verify_cert() {
    local email="$1"
    local username="${email%@*}"
    
    log_info "Verifying certificate for $email"
    
    openssl verify -CAfile "${CA_DIR}/certs/root_CA.crt" \
        "${CA_DIR}/certs/${username}.crt"
    
    openssl x509 -in "${CA_DIR}/certs/${username}.crt" -text -noout
}

# Main script execution
main() {
    local command="$1"
    shift
    
    case "$command" in
        init)
            init_ca
            ;;
        create-root-ca)
            create_root_ca
            ;;
        create-user-cert)
            if [ $# -ne 1 ]; then
                log_error "Usage: $0 create-user-cert <email>"
            fi
            create_user_cert "$1"
            ;;
        verify-cert)
            if [ $# -ne 1 ]; then
                log_error "Usage: $0 verify-cert <email>"
            fi
            verify_cert "$1"
            ;;
        *)
            echo "Usage: $0 {init|create-root-ca|create-user-cert|verify-cert}"
            exit 1
            ;;
    esac
}

# Script entry point
if [ $# -lt 1 ]; then
    echo "Usage: $0 {init|create-root-ca|create-user-cert|verify-cert}"
    exit 1
fi

main "$@"
