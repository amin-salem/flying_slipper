FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv

# In Iran, if PyPI is slow/blocked, build with:
#   docker compose build --build-arg PIP_INDEX_URL=https://mirror-pypi.runflare.com/simple
ARG PIP_INDEX_URL=https://pypi.org/simple
COPY requirements.txt .
RUN pip install --no-cache-dir --index-url "$PIP_INDEX_URL" -r requirements.txt

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini .

RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
# 2 worker processes; raise for a bigger server (about 2 x CPU cores)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--proxy-headers"]
