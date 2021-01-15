# Container image that runs your code
FROM openwrtorg/sdk:i386_pentium4-snapshot

# Copies your code file from your action repository to the filesystem path / of the container
COPY build.sh /build.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/build.sh"]
