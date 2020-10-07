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

**Note for the interested**: The build process is two-stage with the final image only retaining all executables, libraries and include-files to utilize OQS-enabled openssh.

Some runtime configuration options exist that can be optionally set via docker environment variables:

1) Disabling host key re-generation: By setting `REGEN_HOST_KEYS` to `no` the host keys won't automatically be re-generated. Keep in mind that this results in having **no** unique host keys on your running docker container. The default setting is re-generating the host keys.

1) Disabling identity file re-generation: By setting `REGEN_IDS` to `no` the identity files in `~/.ssh/` won't automatically be re-generated. Keep in mind that this results in having **no** unique identity files on your running docker container.

e.g. `docker run -e REGEN_IDS=no -dit oqs-openssh-img`

#### Build type argument(s)

The Dockerfile also facilitates building the underlying OQS library to different specifications (by setting the `--build-arg` variable `LIBOQS_BUILD_DEFINES` as defined [here](https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs).

For example, with this build command
```bash
docker build --build-arg LIBOQS_BUILD_DEFINES="-DOQS_USE_CPU_EXTENSIONS=OFF" -f Dockerfile -t oqs-curl-generic .
``` 
a generic system without processor-specific runtime optimizations is built, thus ensuring execution on all computers (at the cost of maximum runtime performance).

## Usage

Information how to use the image is [available in the separate file USAGE.md](USAGE.md).

## Build options

The Dockerfile provided allows for some customization of the image built:

### LIBOQS_BUILD_DEFINES

This permits changing the build options for the underlying library with the quantum safe algorithms. All possible options are documented [here](https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs).

By default, the image is built such as to have maximum portability regardless of CPU type and optimizations available, i.e. to run on the widest possible range of cloud machines.

### OPENSSH_BUILD_OPTIONS

This allows to configure some additional build options for building OQS-OpenSSH. Those options, if specified, will be appended to the `./configure` command as shown [here](https://github.com/open-quantum-safe/openssh#step-2-build-the-fork). Some parameters are already configured as they are essential to the build: `--with-libs`, `--prefix`, `--sysconfdir`, `--with-liboqs-dir`. 

### INSTALL_DIR

This defines the resultant location of the software installation.

By default this is /opt/oqssa . It is recommended to not change this. Also, all [usage documentation](USAGE.md) assumes this path.

### MAKE_DEFINES

Allow setting parameters to `make` operation, e.g., `-j nnn` where nnn defines the number of jobs run in parallel during build. 

The default is conservative and known not to overload normal machines (`-j 2`). If one has a very powerful (many cores, >64GB RAM) machine, passing larger numbers (or only `-j` for maximum parallelism) speeds up building considerably.

### OQS_USER

Defaults to `oqs`. The docker file creates a non-root user during build. The purpose of this user is to be a login-user for incoming ssh connections. This docker image is designed to be used in a practical way, and having root logging in for simply establishing a connection in a production environment is not considered practical.

### OQS_PASSWORD

Defaults to `oqs.pw`. This is the password for the `OQS_USER`. A password is needed to enable the authentication method 'password' for ssh.