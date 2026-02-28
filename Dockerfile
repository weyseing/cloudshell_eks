# Use a lightweight linux base
FROM debian:bookworm-slim

# Set terminal color settings
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV CLICOLOR_FORCE=1

# Install dependencies and AWS CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    python3 \
    python3-pip \
    bash \
    vim \
    git \
    jq \
    && pip3 install awscli aws-mfa --break-system-packages \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"

# Set the working directory for your scripts
WORKDIR /apps

# Default command to keep the container open
CMD ["tail", "-f", "/dev/null"]
