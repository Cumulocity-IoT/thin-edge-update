###
# this layer uses the image iot-thin-edge-container-bundle and adds projects specific files. This is require dto support PICS and EP5
# The image iot-thin-edge-container-bundle is build in the azure pipeline and contains the latest thin-edge.io version
###

FROM ghcr.io/thin-edge/tedge-container-bundle:20251030.1508 AS release

###
# project specific changes
###

USER root

ENV TEDGE_MQTT_BRIDGE_BUILT_IN=true

# Dummy statement - change this value manually each time
LABEL rebuild=20250617_001

# First, declare the build argument
ARG BUILD_ID
# Then use it to set the environment variable
# ENV VERSION=$BUILD_ID
RUN echo "Build Id: ${BUILD_ID}" > /etc/tedge/buildId


ENV PATH="/command:${PATH}"

# Add custom config

COPY tedge/restart_background.toml /etc/tedge/operations/
COPY tedge/self_update.toml /etc/tedge/operations/
COPY tedge/software_update.toml /etc/tedge/operations/


# Copy workflow
COPY tedge/*.toml /etc/tedge/operations/
RUN chmod 755 /etc/tedge/operations/*.toml


# Copy workflow
COPY tedge/container-image /etc/tedge/sm-plugins/
RUN chmod 755 etc/tedge/sm-plugins/container-image


RUN mkdir /etc/tedge/scripts
COPY tedge/manage-update.sh /etc/tedge/scripts/manage-update.sh
RUN chmod 755 /etc/tedge/scripts/manage-update.sh
COPY tedge/manage-update.sh /etc/tedge/sm-plugins/container-image
RUN chmod 755 /etc/tedge/sm-plugins/container-image

USER "tedge"
# Allow users to re-use the container for one-off commands
# to ensure the thin-edge.io version remains the same
CMD [ "/init" ]