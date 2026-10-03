FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv

# Packages come from server/wheels/ if you filled it with
# tools/download_wheels.sh (works without internet), otherwise from PIP_INDEX_URL.
ARG PIP_INDEX_URL=https://pypi.org/simple
COPY requirements.txt .
COPY wheels/ /wheels/
RUN if ls /wheels/*.whl >/dev/null 2>&1; then \
        pip install --no-cache-dir --no-index --find-links /wheels -r requirements.txt; \
    else \
        pip install --no-cache-dir --timeout 120 --retries 10 --index-url "$PIP_INDEX_URL" -r requirements.txt; \
    fi && rm -rf /wheels

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini .

RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
# 2 worker processes; raise for a bigger server (about 2 x CPU cores)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--proxy-headers"]
