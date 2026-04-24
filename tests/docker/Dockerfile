FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies
RUN apt-get update && apt-get install -y \
    bash \
    git \
    curl \
    sudo \
    fuse3 \
    kcov \
    binutils-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libdw-dev \
    libiberty-dev \
    && rm -rf /var/lib/apt/lists/*

# Set up a test user
RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER tester
WORKDIR /home/tester/mountsync

# Copy the repository (we will mount it as a volume for faster dev, but COPY for the base image)
# COPY . . 

# Command to run tests
CMD ["./tests/libs/bats-core/bin/bats", "tests/"]
