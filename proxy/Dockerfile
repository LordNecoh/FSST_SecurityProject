# proxy/Dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN touch requirements.txt && pip install -r requirements.txt

# We do not copy the code with COPY . . because we use volumes in docker-compose!
# When you go to production, you will remove the volumes and uncomment the line below:
# COPY . .

CMD ["python", "-u", "proxy.py"] 
# Il flag -u evita che Python metta in buffer i print, così vedi i log in tempo reale