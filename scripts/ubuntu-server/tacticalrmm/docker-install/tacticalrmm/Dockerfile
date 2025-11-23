FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    git \
    curl \
    wget \
    gnupg \
    libpq-dev \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create tactical user
RUN useradd -m -s /bin/bash tactical

# Set working directory
WORKDIR /opt/tacticalrmm

# Clone TacticalRMM repository
RUN git clone https://github.com/amidaware/tacticalrmm.git . && \
    chown -R tactical:tactical /opt/tacticalrmm

# Create log directory
RUN mkdir -p /var/log/tacticalrmm && \
    chown -R tactical:tactical /var/log/tacticalrmm

# Switch to tactical user
USER tactical

# Install Python dependencies
WORKDIR /opt/tacticalrmm/api/tacticalrmm
RUN python3 -m venv /opt/tacticalrmm/env && \
    /opt/tacticalrmm/env/bin/pip install --upgrade pip && \
    /opt/tacticalrmm/env/bin/pip install wheel setuptools && \
    /opt/tacticalrmm/env/bin/pip install gunicorn && \
    /opt/tacticalrmm/env/bin/pip install -r requirements.txt

# Add entrypoint script
COPY --chown=tactical:tactical entrypoint.sh /opt/tacticalrmm/entrypoint.sh
RUN chmod +x /opt/tacticalrmm/entrypoint.sh

# Expose port
EXPOSE 8000

# Set environment path
ENV PATH="/opt/tacticalrmm/env/bin:$PATH"

# Entrypoint
ENTRYPOINT ["/opt/tacticalrmm/entrypoint.sh"]