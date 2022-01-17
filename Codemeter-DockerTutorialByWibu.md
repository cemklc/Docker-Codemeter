# CodeMeter in Docker by Wibu
CodeMeter supports Docker since version 6.90. With version 7.30 further support was added to support running CodeMeter in its own standalone container and using it from another container in a shared network.

The following describes how you can:
- Setup a standalone CodeMeter container
- Setup a standalone CmWebAdmin container
- Setup a container with a protected application using the standalone CodeMeter container for licenses
- Setup licenses for a standalone CodeMeter container
  - Using network licenses, with the CodeMeter container acting as a network client
  - Using a CmCloudContainer
  - Using an UFC CmActLicense

The usage of CmDongles inside a container is not recommended. Instead setup a network server with the CmDongle licenses and then use the CodeMeter container as a network client.

With a standalone CodeMeter container you will need to manage multiple container for your application. Therefore the following instructions assume the usage of docker-compose. However docker-compose is not required for this, and you can manage the container individually if you so choose.

## Setup a standalone CodeMeter container

To setup the CodeMeter container,  download the `codemeter-lite` package from our [website](https://www.wibu.com/support/user/user-software.html). It can be found in the user downloads under “CodeMeter User Runtime for Linux” with the description “Driver Only”. In the following instructions the `Linux 64-bit DEB package` is used. 

The codemeter-lite package can simply be extracted in a directory called "deb/Codemeter". In the Docker image CodeMeter will be installed by copying the required files and running the CodeMeter install command on CodeMeterLin.

Additionally a preconfigured `Server.ini` can be used to setup profiling values for CodeMeter. The default file can be copied from the extracted package (`/etc/wibu/CodeMeter/Server.ini`) and values can be adjusted as needed. You can find detailed information on the profiling options in the user manual chapter "Profiling".

Next create the Dockerfile.

*Dockerfile.codemeter*

```dockerfile
FROM  bitnami/minideb:stretch

LABEL description="Customer CodeMeter image"

ARG USE_HTTP_PROXY
ARG USE_HTTPS_PROXY

# set proxy settings
ENV http_proxy $USE_HTTP_PROXY
ENV https_proxy $USE_HTTPS_PROXY

# install needed components
RUN install_packages libusb-1.0-0 libcurl3 

# copy bin files
COPY deb/CodeMeter/usr/bin /usr/bin
COPY deb/CodeMeter/usr/lib /usr/lib
COPY deb/CodeMeter/usr/sbin /usr/sbin

# copy a preconfigured Server.ini
COPY data/etc/Server.ini /etc/wibu/CodeMeter/Server.ini

# copy var files
COPY deb/CodeMeter/var /var

# declare commucation ports
EXPOSE 22350
EXPOSE 22351
EXPOSE 22352
EXPOSE 22353

# Add anonymous VOLUMEs to efficient store changed data
VOLUME  ["/var/log/CodeMeter"]

# Run CodeMeter install command
RUN /usr/sbin/CodeMeterLin -x ; exit 0

# Copy control scripts
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT [ "/entrypoint.sh" ]

# Run default command
CMD ["--server"]
```

Please note:

* The base image `bitnami/minideb:stretch` is used to have a base image that is as small as possible. Alpine Linux is not yet supported.
* The default ports of CodeMeter and the CmWebAdmin are exposed. We expose the CmWebAdmin ports as well so we can later reuse this image for the CmWebAdmin container.
* An entrypoint script is used with a default command `--server` to run CodeMeterLin. This can also be used to run other CodeMeter functionality.

*entrypoint.sh*

```bash
#!/bin/bash
set -e

case "$1" in
   
   '--server')
        exec CodeMeterLin -v
    ;;

   '--webadmin')
        exec CmWebAdmin
    ;;
   
   '--update')
        exec cmu -u
    ;;

   '--cmdust')
        exec cmu --cmdust
    ;;
    
    '--check')
        exec cmu -l
    ;;
   
   *)
        exec "$@"
    ;;
esac
```

To build an and run the container using docker-compose a `docker-compose.yml` needs to be created.

*docker-compose.yml*

```yaml
version: '3.3'
services:  

  codemeter:
    image: customer/codemeter
    container_name: codemeter
    build:
      context: .
      dockerfile: Dockerfile.codemeter
    restart: always
    networks:
      - codemeter_network 

networks:
  codemeter_network:  
```

Please note:

* A named network `codemeter_network` is created for CodeMeter which can later be used to allow other containers to communicate with the CodeMeter container.

Finally build and run the CodeMeter container, with:
`docker-compose up`

## Setup a standalone CmWebAdmin container

To setup the CmWebAdmin container, you can reuse the image we used above for the CodeMeter container. Simply add another service to your `docker-compose.yml` using the previous image.

*docker-compose.yml*

```yaml
version: '3.3'
services:  

  codemeter:
    image: customer/codemeter
    container_name: codemeter
    build:
      context: .
      dockerfile: Dockerfile.codemeter
    restart: always
    networks:
      - codemeter_network 
      
  codemeter_webadmin:
    image: customer/codemeter
    container_name: codemeter_webadmin
    command: --webadmin
    depends_on:
      - codemeter
    restart: always
    ports:
      - "23080:22352"
      - "23443:22353"
    environment:
      CODEMETER_HOST: codemeter
    networks:
      - codemeter_network

networks:
  codemeter_network: 
```

Please note:

* The `command` was changed from the default to `--webadmin`. In the `entrypoint.sh` this will execute CmWebAdmin instead of CodeMeterLin.
* The option `depends_on` was set and references the CodeMeter service. By doing this we ensure the WebAdmin will not be started before CodeMeter is running.
* The option `ports` is used to forward the WebAdmin ports to the host system.
  * Port 22352 is used for HTTP communication.
  * Port 22352 is used for HTTPS communication.
* The environment variable `CODEMETER_HOST` is set to specify the address where the CodeMeter libraries used by the WebAdmin can find the local CodeMeter service.
* The `codemeter_network` is used to make sure the WebAdmin can communicate with CodeMeter.

To be able to access the CmWebAdmin you will also need to enable the remote read access for CmWebAdmin in the `Server.ini`. You can easily do this by using a preconfigured `Server.ini` as mentioned in the previous chapter when settings up the CodeMeter service. The required profiling value is `RemoteRead=2`.

For write access you will need to additionally setup a write password using cmu:
`cmu --set-access-data --password MyPassword`
This can be added to the entrypoint.sh before starting the CmWebAdmin.

Please note that once you setup the password you will need to use HTTPS to connect to the CmWebAdmin. You can enter the password once connected by click the "R" symbol in the navigation menu and choosing "Allow write access".

Finally run `docker-compose up` to build and run everything. You should now be able to reach the CmWebAdmin over http://localhost:23080 and https://localhost:23443. 

## Setup a container with a protected application using the standalone CodeMeter container for licenses

To setup the application container,  download the `axprotector` package from our [website](https://www.wibu.com/support/user/user-software.html). It can be found in the user downloads under “AxProtector Runtime for Linux” . In the following instructions the `Linux 64-bit DEB package` is used. 

The `axprotector` package can simply be extracted in a directory called "deb/AxProtector". In the Docker image the AxProtector runtime will be installed by simply copying the required libraries into the image.

Next create the Dockerfile.

*Dockerfile.app*

```dockerfile
FROM  bitnami/minideb:stretch

LABEL description="Customer application image"

# copy needed CodeMeter libraries
COPY deb/CodeMeter/usr/lib /usr/lib

# copy needed AxProtector libraries
COPY deb/AxProtector/usr/lib /usr/lib

# copy protected application
COPY data/HelloWorld.protected /app/HelloWorld.protected

WORKDIR /app
CMD ["/app/HelloWorld.protected"]
```

Please Note:

* The protected application may require both CodeMeter and AxProtector libraries.
* If the application is unprotected and only CodeMeter API is used, the CodeMeter libraries should be sufficient.
* Native protected applications don't require any AxProtector libraries. 
* For native protected application, if during encryption the -x parameter was used to statically link the CodeMeter library, you won't need the CodeMeter libraries either unless you perform additional Core API calls from your code.
  **Important:** Make sure you encrypted with AxProtector Version 10.80 or newer to ensure the statically linked library will use the `CODEMETER_HOST` environment variable.

In the `docker-compose.yml`, add the new service:

```yaml
  application:
      image: customer/application
      build:
        context: .
        dockerfile: Dockerfile.app
      depends_on:
        - codemeter
      environment:
        CODEMETER_HOST: codemeter 
      networks:
        - codemeter_network
```

Please note:

* The option `depends_on` was set and references the CodeMeter service. By doing this we ensure the protected application will not be started before CodeMeter is running.
* The environment variable `CODEMETER_HOST` is set to specify the address where the CodeMeter libraries used by the protected application can find the local CodeMeter service.
* The `codemeter_network` is used to make sure the CodeMeter libraries can communicate with CodeMeter.
* If you have multiple apps it might make sense to create a base image for the CodeMeter libraries and use this for all your apps that use CodeMeter.

Finally run `docker-compose up` to build and run everything. You should now see the output of your protected application.** Most likely you will see an error that the license is missing.**

## Setup licenses for a standalone CodeMeter container

### Using network licenses, with the CodeMeter container acting as a network client

To use network licenses CodeMeter by default will perform UDP broadcasts to try and reach a network server. It is recommended however to specifically specify the server in the `Server Search List` of the `Server.ini`.

To do this the preconfigured `Server.ini` can be used with a placeholder:

```ini
[ServerSearchList]
UseBroadcast=1

[ServerSearchList\Server1]
Address=255.255.255.255
```

In this case the broadcast address `255.255.255.255` was used. This means that if the value is not overwritten, a broadcast is performed as fallback.

In the `entrypoint.sh` you can now add the following to replace the placeholder with the environment variable `LICENSE_SERVER`.

```bash
'--server')
	sed -i "s/255.255.255.255/$LICENSE_SERVER/" /etc/wibu/CodeMeter/Server.ini
	exec CodeMeterLin -v
;;
```

In the `docker-compose.yml` the `LICENSE_SERVER` environment variable then needs to be defined for the CodeMeter service:

```yaml
codemeter:
    [...]
    environment: 
      LICENSE_SERVER: 123.123.123.123
```

Finally run `docker-compose up` to build and run everything. The CodeMeter container should now search for licenses on the specified license server. 

### Using a CmCloudContainer

A CmCloudContainer can be used by importing the Cloud Credentials using cmu. To do this an additional container for handling licenses can be used.

First create the following Dockerfile.

*Dockerfile.license*

```dockerfile
FROM bitnami/minideb:stretch

LABEL description="Customer License image"

# set default license path
ENV LICENSE_PATH /licenses

# set default CodeMeter Host container name.
ENV CODEMETER_HOST ""

# set proxy settings
ARG USE_HTTP_PROXY
ARG USE_HTTPS_PROXY
ENV http_proxy $USE_HTTP_PROXY
ENV https_proxy $USE_HTTPS_PROXY

# install needed components, needed for cmu
RUN install_packages libusb-1.0-0

# copy bin files
COPY deb/CodeMeter/usr/bin/cmu /usr/bin/cmu
COPY deb/CodeMeter/usr/lib /usr/lib

# copy entrypoint script
COPY license.sh /license.sh
RUN sed -i 's/\r$//' /license.sh
RUN ["chmod", "+x", "/license.sh"]

# copy cloud licenses to install
COPY data/licenses /licenses

# set entrypoint
ENTRYPOINT [ "/license.sh" ]


# install licenses by default
CMD ["--install"]
```

Note:

* This container will contain the command line tool `cmu` and the required libraries. `cmu` can be used to perform to import the CloudCredentials into CodeMeter.
* The environment variable `CODEMETER_HOST` is set to specify the address where the CodeMeter libraries used by `cmu` can find the local CodeMeter service.
* The Cloud Credentials need to be placed into the directory `data\licenses`. The Dockerfile will then copy the credentials into the image. 
* An entry point script `license.sh` is used with the default command `--install`.
* The environment variable `LICENSE_PATH` is defined and used by the entryscript to locate the credential file in the container.

*license.sh* 

```bash
#!/bin/bash
set -e

case "$1" in
   
    '--install')
        for license in $LICENSE_PATH/*; do
            f="$(basename -- $license)"
            printf "\nLicense file: ${f}\n"
            cmu -i -f "${license}" || true
            printf "===========================\n"
        done
        # update license time after installation.
        exec cmu -u
    ;;
  
    '--remove')
        if [ ! -z "$2" ] ; then
            cmu --delete-cmcloud-credentials -s$2 || cmu --del --serial $2
        else
            printf "\nERROR: a license serial was not set!\n"
        fi
    ;;

    '--update')
        exec cmu -u
    ;;

    '--cmdust')
        exec cmu --cmdust
    ;;
    
    '--list')
        exec cmu -l
    ;;

    '--show')
        exec cmu -x
    ;;

    '--showall')
        exec cmu -n --all-servers
    ;;

    *)
        exec "$@"
    ;;
esac
```

Next add the new service to the `docker-compose.yml` for the license.

*docker-compose.yml*

```yaml
  license:
    image: customer/license
    build:
      context: .
      dockerfile: Dockerfile.license
    depends_on:
      - codemeter
    environment:
      CODEMETER_HOST: codemeter
    networks:
      - codemeter_network
```

On startup the license container will now import the CloudCredentials and make the CmCloudContainer available.

You can add a dependency to this service in your application service, to ensure the license will be available for the protected application.

```yaml
  application:
      [...]
      depends_on:
        - codemeter
        - license
```

Finally build and run the container.

```bash
docker-compose up
```

### Using a CmActLicense

By default a normal Smart-Bind CmActLicense cannot be imported when running in Docker. The License Information File (*.WibuCmLIF) needs to fulfill certain conditions to be able to be imported in a Docker environment.

* CmActLicense FirmCode CmActLicenses (FirmCode 5.xxx.xxx)
  * Binding Schema 'none' and CmAct Option 'reimport'
* UFC CmActLicenses (FirmCode 6.xxx.xxx)
  * Binding Schema 'none' and CmAct Option 'reimport'
    OR
  * Binding Schema 'smart' and CmAct Option 'container'

In the following a CmAct-Docker.WibuCmLif is used that was generated using CmBoxPgm and the following parameters:

```bash
cmboxpgm -f6000010 -lif:"CmAct-Docker.WibuCmLif" -lpn:"Docker Test License" -lfs:smart -lopt:vm,container -lpid:2100
```

To enable the license to be persistent and not be deleted on the next container restart or when the image needs to be rebuild, the container needs a named volume for the CmAct directory of CodeMeter.
Additionally we need to mount the Docker Socket to allow CodeMeter in the Docker Container to bind the license to the volume.

To achieve this the CodeMeter service in the `docker-compose.yml` can be adjusted as following:

```yaml
services:

  codemeter:
    [...]
    volumes: 
      - licenses_volume:/var/lib/CodeMeter/CmAct
      - /var/run/docker.sock:/var/run/docker.sock:rw
	  
volumes:
  licenses_volume:
    driver: local  
```

Now the container can be started again.

```bash
docker-compose up codemeter
```

The docker command `docker cp` can be used to copy files between the host system and the container. Additionally the docker command `docker exec` can be used to run `cmu` in the container to import the LIF, create a context file and then import the update file programmed based on the context file.

```bash
# Copy LIF into Docker container
docker cp CmAct-Docker.WibuCmLif codemeter:/tmp/CmAct-Docker.WibuCmLif

# Import LIF file
docker exec -it codemeter cmu --import --file /tmp/CmAct-Docker.WibuCmLif

# Create context file
docker exec -it codemeter cmu --context 6000010 --serial 130-150197269 --file /tmp/context.WibuCmRaC

# Copy context file from Docker container to host
docker cp codemeter:/tmp/context.WibuCmRaC .

# Use CmBoxPgm to activate the license with product code 1
cmboxpgm -f6000010 -cau -p1 -cau -laf:"context.WibuCmRaC","update.WibuCmRaU"

# Copy update file into container
docker cp update.WibuCmRaU codemeter:/tmp/update.WibuCmRaU

# Import update file
docker exec -it codemeter cmu --import --file /tmp/update.WibuCmRaU
```

The license does not have to be created using CmBoxPgm. Alternatively the file base activation of the CodeMeter License Central can be used.

Once the license is activated it will be persisted in the named volume and the protected application can be started.

```bash
docker-compose up
```

