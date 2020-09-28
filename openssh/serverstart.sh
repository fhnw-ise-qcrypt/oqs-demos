#!/bin/sh

# Optionally set KEM to one defined in https://github.com/open-quantum-safe/openssl#key-exchange
# if [ "x$KEM" == "x" ]; then
# 	export KEM=kyber-512
# fi

# # Optionally set server certificate alg to one defined in https://github.com/open-quantum-safe/openssl#authentication
# # The root CA's signature alg remains as set when building the image
# if [ "x$SIG" != "x" ]; then
#     cd /opt/oqssa/bin
# fi

# Start a TLS1.3 test server based on OpenSSL accepting only the specified KEM_ALG
# openssl s_server -cert /opt/test/server.crt -key /opt/test/server.key -curves $KEM_ALG -www -tls1_3 -accept localhost:4433&

# Start the OQS SSH Daemon with the configuration as in /opt/oqssa/sshd_config
/opt/oqssa/sbin/sshd

# Open a shell for local experimentation
sh
