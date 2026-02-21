# Use a lightweight linux base
FROM alpine:3.18

# Install dependencies and AWS CLI
RUN apk add --no-cache \
    curl \
    python3 \
    py3-pip \
    bash \
    && pip install awscli aws-mfa

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Set the working directory for your scripts
WORKDIR /apps

# Default command to keep the container open
CMD ["tail", "-f", "/dev/null"]
