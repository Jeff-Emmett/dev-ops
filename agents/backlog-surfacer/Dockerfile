FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY surfacer.py .
COPY config.yml .

ENTRYPOINT ["python", "surfacer.py"]
CMD ["morning", "--dry-run"]
