FROM mathworks/matlab:r2024b AS base

# Switch to root user for system package installation
USER root

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    cmake \
    openssl \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set MQTT version
ENV MQTT_VERSION="1.3.10"

# Create a temporary directory for building
WORKDIR /tmp/paho

# Install Paho MQTT libraries
RUN wget https://github.com/eclipse/paho.mqtt.c/archive/refs/tags/v${MQTT_VERSION}.tar.gz \
    && tar -xzf v${MQTT_VERSION}.tar.gz \
    && cd paho.mqtt.c-${MQTT_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /tmp/paho

# Create symbolic links for required libraries
RUN rm -f /usr/local/lib/libpaho-mqtt3as.so.1 && \
    ln -s /usr/local/lib/libpaho-mqtt3a.so.1 /usr/local/lib/libpaho-mqtt3as.so.1

# Create necessary directories
RUN mkdir -p /opt/matlab/R2024b/toolbox/icomm/mqtt \
    /opt/matlab/R2024b/toolbox/icomm/icomm \
    /opt/matlab/R2024b/toolbox/icomm/apps \
    /opt/matlab/R2024b/toolbox/icomm/modbus \
    /opt/matlab/R2024b/toolbox/icomm/opc \
    /opt/matlab/R2024b/toolbox/icomm/osisoftpi \
    /opt/matlab/R2024b/toolbox/instrument \
    /home/matlab/Documents/MATLAB/scripts

# Copy toolboxes
COPY scripts/Add-Ons/icomm/mqtt /opt/matlab/R2024b/toolbox/icomm/mqtt
COPY scripts/Add-Ons/icomm/icomm /opt/matlab/R2024b/toolbox/icomm/icomm
COPY scripts/Add-Ons/icomm/apps /opt/matlab/R2024b/toolbox/icomm/apps
COPY scripts/Add-Ons/icomm/modbus /opt/matlab/R2024b/toolbox/icomm/modbus
COPY scripts/Add-Ons/icomm/opc /opt/matlab/R2024b/toolbox/icomm/opc
COPY scripts/Add-Ons/icomm/osisoftpi /opt/matlab/R2024b/toolbox/icomm/osisoftpi
COPY scripts/Add-Ons/instrument /opt/matlab/R2024b/toolbox/instrument

# Copy startup.m to the correct location
COPY scripts/startup.m /home/matlab/Documents/MATLAB/startup.m

# Set permissions for MATLAB user (only for specific directories)
RUN chown -R matlab:matlab /opt/matlab/R2024b/toolbox/icomm \
    && chown -R matlab:matlab /opt/matlab/R2024b/toolbox/instrument \
    && chown -R matlab:matlab /home/matlab/Documents/MATLAB/scripts \
    && chown matlab:matlab /home/matlab/Documents/MATLAB/startup.m

# Create entrypoint script
RUN echo '#!/bin/bash\n\
exec matlab -licmode onlinelicensing' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Switch back to MATLAB user
USER matlab

# Set environment variables
ENV MATLAB_USE_INTERNET=true
ENV MATLAB_ADDONS_INSTALL_DIR=/opt/matlab/R2024b/
ENV LD_LIBRARY_PATH=/usr/local/lib:/opt/matlab/R2024b/toolbox/icomm/mqtt/mqtt/bin/glnxa64:/opt/matlab/R2024b/bin/glnxa64

# Set working directory
WORKDIR /home/matlab/Documents/MATLAB

# Expose ports
EXPOSE 8888 12345

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]