# Container image that runs your code
FROM openwrtorg/sdk:arm_mpcore-snapshot

# Copies your code file from your action repository to the filesystem path / of the container
COPY build.sh /build.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/build.sh"]
