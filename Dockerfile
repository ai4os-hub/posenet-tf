# Dockerfile may have two Arguments: tag, branch
# tag - tag for the Base image, (e.g. 1.10.0-py3 for tensorflow)
# branch - user repository branch to clone (default: master, other option: test)
ARG tag=1.14.0-py3

# Base image, e.g. tensorflow/tensorflow:1.12.0-py3
FROM tensorflow/tensorflow:${tag}

# Add container's metadata to appear along the models metadata
ENV CONTAINER_MAINTAINER "Lara Lloret Iglesias <lloret@ifca.unican.es>"
ENV CONTAINER_VERSION "0.1"
ENV CONTAINER_DESCRIPTION "DEEP as a Service Container: Posenet"

# What user branch to clone (!)
ARG branch=main
# If to install JupyterLab
ARG jlab=true
# Oneclient version
ARG oneclient_ver=19.02.0.rc2-1~bionic

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         psmisc \
         python3-setuptools \
         python3-pip \
         python3-wheel && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    python --version && \
    pip --version

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*
    
# Install oneclient for ONEDATA
RUN curl -sS  http://get.onedata.org/oneclient-1902.sh | bash -s -- oneclient="$oneclient_ver" && \
    apt-get clean && \
    mkdir -p /mnt/onedata && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Install deep-start script
# N.B.: This repository also contains run_jupyter.sh
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start && \
    ln -s /srv/.deep-start/run_jupyter.sh /usr/local/bin/run_jupyter

# Install FLAAT (FLAsk support for handling Access Tokens)
RUN pip install --upgrade pip && \
    pip install --no-cache-dir flaat && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

# Install DEEPaaS from PyPi:
RUN pip install --no-cache-dir deepaas && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Useful tool to debug extensions loading
RUN pip install --no-cache-dir entry_point_inspector && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Install DEEP debug_log scripts:
RUN git clone https://github.com/deephdc/deep-debug_log /srv/.debug_log

# Install JupyterLab
ENV JUPYTER_CONFIG_DIR /srv/.jupyter/
ENV SHELL /bin/bash
RUN if [ "$jlab" = true ]; then \
       pip install --no-cache-dir jupyterlab ; \
       git clone https://github.com/deephdc/deep-jupyter /srv/.jupyter ; \
    else echo "[INFO] Skip JupyterLab installation!"; fi

# Update OpenCV packages
RUN apt-get update && \
    apt-get install -y libsm6 libxext6 libxrender-dev

# Install user app:
RUN git clone -b $branch https://github.com/ai4os-hub/posenet-tf.git && \
    cd posenet-tf && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Open DEEPaaS port
EXPOSE 5000

# Open Monitoring port
EXPOSE 6006

# Open JupyterLab port
EXPOSE 8888

# Account for OpenWisk functionality (deepaas >=0.4.0) + proper docker stop
CMD ["deepaas-run","--listen-ip", "0.0.0.0", "--listen-port", "5000"]
