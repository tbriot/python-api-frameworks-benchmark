FROM python:3.6-slim

LABEL maintainer="Thomas Briot"

WORKDIR /usr/src/app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY src .

ENV FLASK_APP=/usr/src/app/api.py

EXPOSE 5000

ENTRYPOINT ["flask", "run", "--host=0.0.0.0"]