# server/Dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN touch requirements.txt && pip install -r requirements.txt

CMD ["python", "-u", "server.py"]
# -u flag prevents Python from buffering prints, so you see logs in real time