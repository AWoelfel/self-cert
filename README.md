
# Self Cert

A tool set for creating self-signed certificates for LAN SSL server hosting.

## Main Concepts

This stack is based on OpenSSL. It uses OpenSSL to create self-signed certificates for testing purposes or local deployments.
I do not recommend using this stack in production at all!

The key points : 
- Configuration is streamlined and kept as easy as possible.
- Everything is bound by naming conventions. (i.e. all files are named after the domain they are for + a suffix)
- All files with sensitive data (i.e. private keys) are encrypted with the mechanism of your choice and will be stored inside the repository! (see below)
- The simplified certification deployment is used; so no certificate revocation/ serial or index files are created nor available.


## Before you start!

There are some settings you should change before you start.

### Primary self-signed CA & common naming configuration

- change `configs/common.cnf` to your liking

        # COMMON AUTHORITY SETTINGS
        [ req_distinguished_name ]
        C            = <COUNTRY>
        ST           = <STATE>
        L            = <CITY>
        O            = <ORGANIZATION>
        OU           = <DEPARTMENT>
        emailAddress = <EMAIL>

- change `configs/root_ca.cnf` to your liking

       # MAIN CERTIFICATE AUTHORITY NAMING            
       [ req_distinguished_name ]
       CN           = <COMMON AUTHORITY NAME>

### Encryption

This stack relies on external encryption mechanisms to protect sensitive data.
The encryption must be configured before the first run. 

An example with the expected input and output value is provided in `copy_crypt.sh`.

A second example with ansilbe vault as possible backend is provided in `ansible_vault_crypt.sh`.
The ansilbe vault backend assumes that you have ansilbe vault installed and configured.

To configure your choice for encryption use the file ``.env`` and set the environment variable ``CRYPTO_BACKEND``.
The value for ``CRYPTO_BACKEND`` is a relative path to a script that will be executed each time encryption/decryption is required.
The call arguments are : 

````shell
./your_shell_script.sh <MODE> <INPUT FILE> <OUTPUT FILE>

# MODE will be either "encrypt" or "decrypt"
# INPUT FILE is the path to the file to encrypt/decrypt
# OUTPUT FILE is the path to the output file
````

> [!WARNING]
> By default ``copy_crypt.sh`` is configured as a dummy encryption backend. This does not encrypt anything!


## Certificate creation

From the root directory of this repository run ``make shell`` to enter the cert creation container.

Make targets are available for all artifacts created by this stack.
Here is a list:

| Target               | Description                                                                                  |
|----------------------|----------------------------------------------------------------------------------------------|
| init                 | Initially create directory structure and ROOT CA                                             |
| clean                | Encrypt and remove (plaintext) private keys (so they do not get persisted in the repository) |
| lock                 | Encrypt sensitive files                                                                      |
| certs/%.crt          | Sign CSR and generate certificate for domain                                                 |
| certs/wildcard_%.crt | Sign CSR and generate wildcard certificate                                                   |
| certs/%.pem          | Create combined PEM file with cert and CA cert (aka. full cert chain)                        |

````shell
#Examples

# creates full chain certificate file for '*.git.lan'
make certs/wildcard_git.lan.pem    

# creates single file for 'myhost.local'
make certs/myhost.local.crt        

# creates a singning request for '*.myhost.local'             
make csr/wildcard_myhost.local.csr     

# creates a private key for 'myhost.local' or used configured decryption to decode an existing key              
make private/myhost.local.key     
````

## Customize Certificates

During a certificate creation step a signing request is created.
If you want to customize the signing request parameters, you can do so by creating the corresponding file in the ``csr`` directory.

An example can be found in `exmaples/app0.mgmt.local_req.cnf`.
This file is used to prepare a SSL certificate for a local PROXMOX hypervisor.

If a prepared ``cnf`` file is found, it will be used instead of creating a new one.
A on the fly created ``cnf`` will be deleted (intermediate make build target)


## Certificate usage

During ``make init`` the ROOT CA is created and stored in two places. The file ``./rootCA.crt`` can be added to the trusted CA store of your system.

Any certificate creation like ``make certs/%.pem`` or ``make certs/%.crt`` will create the certificate and a corresponding private key.
Those are to be placed in your webserver for TLS/SSL/HTTPS connections.

