# Makefile for Local Network SSL Certificate Generation
SHELL := /bin/bash

.PRECIOUS: csr/%.csr csr/wildcard_%.csr certs/%.crt certs/wildcard_%.crt
.DEFAULT_GOAL := help

KNOWN_PRIVATE_KEYS = $(wildcard private/*.key)
LOCKED_PRIVATE_KEYS = $(KNOWN_PRIVATE_KEYS:.key=.key_locked)


##########################################################################
## Setup
##########################################################################

# Setup directory structure and files
.PHONY: setup
setup:
	mkdir -p ./private ./certs ./csr
	chmod 700 ./private

.PHONY: init
init: setup certs/ca.crt

##########################################################################
## ROOT CA
##########################################################################

# Create Root CA
rootCA.crt: private/ca.key setup
	[ -f "$@" ] || openssl req -batch -verbose -config ./configs/root_ca.cnf -key private/ca.key -new -x509 -sha256 -days 3650 -extensions v3_ca -out "$@"

certs/ca.crt: rootCA.crt
	[ -f "$@" ] || cp "$<" "$@"


##########################################################################
## Cleaning
##########################################################################
# Clean up
.PHONY: clean lock
clean: lock
	rm -rf ./private/*.key

##########################################################################
## Pre-Commit preps & encryption / decryption
##########################################################################

# encrypt sensitives
.PHONY: lock
lock: $(LOCKED_PRIVATE_KEYS)

%_locked: %
	$(CRYPTO_BACKEND) "encrypt" "$<" "$@"

define decrypt-locked-file-or-fallback
	if [ -f "$@_locked" ]; then \
		$(CRYPTO_BACKEND) "decrypt" "$(@)_locked" "$@"; \
		touch -r "$@_locked" "$@"; \
		chmod 600 "$@"; \
	else \
		$(2); \
	fi
endef

private/%.key:
	$(call decrypt-locked-file-or-fallback,$@,openssl genrsa -out "$@" 2048 && chmod 600 "$@")

##########################################################################
## Signing Requests
##########################################################################

configs/%_req.cnf:
	cp configs/req.cnf "$@"
	echo -e "\n[req_distinguished_name]\nCN=$*\n\n[alt_names]\nDNS.1=$*" >> "$@"

configs/wildcard_%_req.cnf:
	cp configs/req.cnf "$@"
	echo -e "\n[req_distinguished_name]\nCN=*.$*\n\n[alt_names]\nDNS.1=*.$*\nDNS.2=$*" >> "$@"

csr/%.csr: private/%.key configs/%_req.cnf
	openssl req -batch -verbose -new -key "$<" -config "configs/$*_req.cnf" -out "$@"
	$(MAKE) "$<_locked"
	rm "$<"


csr/wildcard_%.csr: private/%.key configs/wildcard_%_req.cnf
	openssl req -batch -verbose -new -key "$<" -config "configs/wildcard_$*_req.cnf" -out "$@"
	$(MAKE) "$<_locked"
	rm "$<"

##########################################################################
## Signing
##########################################################################

certs/%.crt: csr/%.csr certs/ca.crt private/ca.key
	openssl x509 -req -in "$<" -CA certs/ca.crt -CAkey private/ca.key -CAcreateserial -days 3650 -sha256 -copy_extensions copy -extfile configs/server_cert.cnf -extensions server_cert -out "$@"
	$(MAKE) clean

certs/%.pem: certs/%.crt
	cat certs/$*.crt certs/ca.crt > $@
	$(MAKE) clean

##########################################################################
## Runtime
##########################################################################

.PHONY: build-docker-shell
build-docker-shell:
	podman build -t self-cert-shell-runtime --target runtime .

.PHONY: shell
shell: build-docker-shell
	podman run -ti --rm -v ${CURDIR}:/opt/app --env-file=.env self-cert-shell-runtime



##########################################################################
## Runtime
##########################################################################

.PHONY: help
help:
	@echo ""
	@echo "CERTIFICATE CREATION"
	@echo "--------------------"
	@echo "Available targets:"
	@echo ""
	@echo "init                  - Create directory structure and ROOT CA "
	@echo "clean                 - Remove private keys"
	@echo "lock                  - Encrypt sensitive files"
	@echo "certs/%.crt           - Sign CSR and generate certificate for domain"
	@echo "certs/wildcard_%.crt  - Sign CSR and generate wildcard certificate"
	@echo "certs/%.pem           - Create combined PEM file with cert and CA cert (aka. full cert chain)"
	@echo "build-docker-shell    - Build container runtime environment"
	@echo "shell                 - Start shell in container runtime"
	@echo ""
	@echo ""
	@echo "examples:"
	@echo ""
	@echo "make certs/wildcard_git.lan.pem        creates full chain certificate file for '*.git.lan'"
	@echo "make certs/myhost.local.crt            creates single file for 'myhost.local'"
	@echo "make csr/wildcard_myhost.local.csr     creates a singning request for '*.myhost.local'"
	@echo ""

