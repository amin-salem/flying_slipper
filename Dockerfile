# Builds ONLY the game server (server/ folder) - used by Liara's GitHub deploy,
# which builds from the top of the repository.
# For local Docker use server/docker-compose.yml instead.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONPATH=/srv
WORKDIR /srv

COPY server/requirements.txt .
RUN pip install --no-cache-dir --timeout 120 --retries 10 -r requirements.txt

COPY server/app ./app
COPY server/alembic ./alembic
COPY server/alembic.ini server/start.sh ./

RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
# start.sh: "alembic upgrade head" (creates/updates tables), then the API on port 8000
CMD ["sh", "./start.sh"]
