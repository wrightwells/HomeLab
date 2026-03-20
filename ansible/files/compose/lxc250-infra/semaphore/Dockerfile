FROM semaphoreui/semaphore:latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ansible \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    software-properties-common \
    unzip \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo ${VERSION_CODENAME}) main" > /etc/apt/sources.list.d/hashicorp.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends terraform \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
