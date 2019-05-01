FROM python:3.6-alpine

LABEL maintainer="Thomas Briot"

# Add edge community repository
RUN echo "@edge-community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk update \
    && apk add py-gevent gcc musl-dev 

WORKDIR /usr/src/app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY src .

ENV FLASK_APP=/usr/src/app/api.py

EXPOSE 8000

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8000", "api:app"]
CMD ["--help"]