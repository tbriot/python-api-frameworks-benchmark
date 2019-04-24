FROM python:3.6-alpine

LABEL maintainer="Thomas Briot"

RUN apk add gcc musl-dev zlib-dev libffi-dev openssl-dev ca-certificates

WORKDIR /usr/src/app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY src .

ENV FLASK_APP=/usr/src/app/api.py

EXPOSE 8000

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8000", "api:app"]
CMD ["--help"]