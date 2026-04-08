FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir flask requests schedule apscheduler

COPY src/connector.py /app/connector.py

EXPOSE 8080

ENV IMAGE_TAG=0.1.0
ENV LOG_LEVEL=INFO
ENV SERVICE_HOST=0.0.0.0
ENV SERVICE_PORT=8080
ENV GRIST_BASE_URL=http://grist:8484
ENV DRY_RUN=true

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)"

CMD ["python", "connector.py"]
