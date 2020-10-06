## Purpose 

This directory contains a Dockerfile that builds the [OQS OpenSSH fork](https://github.com/open-quantum-safe/openssh), which allows to establish a quantum-safe SSH connection using quantum-safe keys and quantum-safe authentication.

## Quick start

[Install Docker](https://docs.docker.com/install) and run the following commands in this directory:

1. Run `docker build -t oqs-openssh-img .` This will generate the image with a default QSC algorithm (`p256-dilithium2` -- see Dockerfile to change this).
2. `docker run --name oqs-openssh-server -ditp 2222:2222 --rm oqs-openssh-img`
This will start a docker container that has sshd listening for SSH connections on port 2222 and this port is forwarded to and accessible via `localhost:2222`.
3. `docker run --rm --name oqs-openssh-client -dit oqs-openssh-img` will start a docker container with the same properties as `oqs-openssh-server` except the port 2222 is not published.
4. You can hop on either of those two containers as a non-root user (oqs) to use the built in OQS-OpenSSH binaries or do other shenanigans by typing
`docker exec -ti -u oqs oqs-openssh-server /bin/sh`
Of course adjust the container's name accordingly if hopping onto the client.
5. To figure out the target IP, you can type `docker exec -ti -u oqs oqs-openssh-server ifconfig` and look at the IP address of the `eth0` interface.
6. Then connect to the server by typing `docker exec -ti -u oqs oqs-openssh-client ssh <target-ip>` and authenticating the user `oqs` with it's default password `oqs.pw`.

As server and client are based on the same image, connecting from the server to the client's ssh daemon is possible as well.

## More details

The Dockerfile 
- obtains all source code required for building the quantum-safe cryptography (QSC) algorithms and the QSC-enabled version of OpenSSH (7.9-2020-08_p1) 
- builds all libraries and applications
- by default creates host-keys based on the enabled host-key algorithms in `sshd_config` 
- by default creates new identity files based on the already existent id files that where created during build
- by default starts the openssh daemon.

The signature algorithm for the host-key and the identity file is set to `p256-dilithium2` by default, but can be changed to any of the [supported OQS signature algorithms](https://github.com/open-quantum-safe/openssh#digital-signature) with the build argumemt to docker `--build-arg SIG_ALG=`*name-of-oqs-sig-algorithm*, e.g. as follows:
```
docker build -t oqs-curl --build-arg SIG_ALG=qteslapiii .
```

**Note for the interested**: The build process is two-stage with the final image only retaining all executables, libraries and include-files to utilize OQS-enabled curl and openssl.

Two further, runtime configuration option exist that can both be optionally set via docker environment variables:

1) Setting the key exchange mechanism (KEM): By setting 'KEM_ALG' 
to any of the [supported KEM algorithms built into OQS-OpenSSL](https://github.com/open-quantum-safe/openssl#key-exchange) one can run TLS using a KEM other than the default algorithm 'kyber512'. Example: `docker run -e KEM_ALG=newhope1024cca -it oqs-curl`. It is always necessary to also request use of this KEM algorithm by passing it to the invocation of `curl` with the `--curves` parameter, i.e. as such in the same example: `curl --curves newhope1024cca https://localhost:4433`.

2) Setting the signature algorithm (SIG): By setting 'SIG_ALG' to any of the [supported OQS signature algorithms](https://github.com/open-quantum-safe/openssl#authentication) one can run TLS using a SIG other than the one set when building the image (see above). Example: `docker run -e SIG_ALG=picnicl1fs -it oqs-curl`.

#### Build type argument(s)

The Dockerfile also facilitates building the underlying OQS library to different specifications (by setting the `--build-arg` variable `LIBOQS_BUILD_DEFINES` as defined [here](https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs).

For example, with this build command
```
docker build --build-arg LIBOQS_BUILD_DEFINES="-DOQS_USE_CPU_EXTENSIONS=OFF" -f Dockerfile -t oqs-curl-generic .
``` 
a generic system without processor-specific runtime optimizations is built, thus ensuring execution on all computers (at the cost of maximum runtime performance).

## Usage

Information how to use the image is [available in the separate file USAGE.md](USAGE.md).

## Build options

The Dockerfile provided allows for significant customization of the image built:

### LIBOQS_BUILD_DEFINES

This permits changing the build options for the underlying library with the quantum safe algorithms. All possible options are documented [here](https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs).

By default, the image is built such as to have maximum portability regardless of CPU type and optimizations available, i.e. to run on the widest possible range of cloud machines.

### OPENSSL_BUILD_DEFINES

This permits changing the build options for the underlying openssl library containing the quantum safe algorithms. 

The default setting defines a range of default algorithms suggested for key exchange. For more information see [the documentation](https://github.com/open-quantum-safe/openssl#default-algorithms-announced).

### SIG_ALG

This defines the quantum-safe cryptographic signature algorithm for the internally generated (demonstration) CA and server certificates.

The default value is 'dilithium3' but can be set to any value documented [here](https://github.com/open-quantum-safe/openssl#authentication).


### INSTALL_PATH

This defines the resultant location of the software installatiion.

By default this is '/opt/oqssa'. It is recommended to not change this. Also, all [usage documentation](USAGE.md) assumes this path.

### CURL_VERSION

This defines the curl software version to be build into the image.

The default version set is known to work OK and depends on a patch. Therefore changing it is *not* recommended.

### MAKE_DEFINES

Allow setting parameters to `make` operation, e.g., '-j nnn' where nnn defines the number of jobs run in parallel during build.

The default is conservative and known not to overload normal machines. If one has a very powerful (many cores, >64GB RAM) machine, passing larger numbers (or only '-j' for maximum parallelism) speeds up building considerably.

