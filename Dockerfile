FROM nginx:alpine

RUN apk add --no-cache wget unzip bash curl git tar openssl jq procps tzdata zip

COPY file/* /app/

WORKDIR /app

RUN chmod +x start.sh backup.sh restore.sh restart.sh renew.sh

EXPOSE 80 443

ENTRYPOINT ["/app/start.sh"]
