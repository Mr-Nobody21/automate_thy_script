FROM python:3.11-slim

WORKDIR /app

COPY . .

RUN python -m venv venv
RUN ./venv/bin/pip install --upgrade pip && ./venv/bin/pip install -r requirements.txt

ENTRYPOINT ["./venv/bin/python", "fetcher.py"]
