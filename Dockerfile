FROM r.j3ss.co/img:v0.5.7 as release

# Switch to root to install
USER root
ENV USER root
ENV HOME /root

RUN apk add --no-cache \
    coreutils \
    bash \
    curl \
    git \
    jq \
    make

COPY bin/* /usr/local/bin/

RUN set -ex; \
    curl -L https://github.com/geofffranks/spruce/releases/download/v1.18.2/spruce-linux-amd64 -o /usr/bin/spruce && \
    chmod +x /usr/bin/spruce && \
    spruce -v && \
    mkdir -p /src $HOME && \
    echo ". /usr/local/bin/init-toolchain" > $HOME/.bashrc

ENV DOCKER img
ENV BASH_ENV /usr/local/bin/init-toolchain
WORKDIR /src

ENTRYPOINT ["/bin/bash", "-c"]
CMD []

# Switch back to user for security
# Can't do this until we can eliminate sanitize_cgroups from concourse tasks
#USER user
#ENV USER user
#ENV HOME /home/user
