#!/bin/bash

# mode will be "encrypt" for encryption and "decrypt" for decryption
MODE="${1}"

# the file which shall be encrypted or decrypted respectively
INPUT="${2}"

# the file which will be used to store the encryption result or decryption result
OUTPUT="${3}"

# dummy! DO NOT USE THIS :D
cp "${INPUT}" "${OUTPUT}"
