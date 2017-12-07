# Dockerfile for https://github.com/adnanh/webhook

FROM        alpine:3.6

MAINTAINER  Almir Dzinovic <almirdzin@gmail.com>

ENV         GOPATH /go
ENV         SRCPATH ${GOPATH}/src/github.com/adnanh
ENV         WEBHOOK_VERSION 2.6.6

RUN         apk add --update -t build-deps go git libc-dev gcc libgcc && \
            apk add --update curl openssl ca-certificates && \
            curl -L -o /tmp/webhook-${WEBHOOK_VERSION}.tar.gz https://github.com/adnanh/webhook/archive/${WEBHOOK_VERSION}.tar.gz && \
            mkdir -p ${SRCPATH} && tar -xvzf /tmp/webhook-${WEBHOOK_VERSION}.tar.gz -C ${SRCPATH} && \
            mv -f ${SRCPATH}/webhook-* ${SRCPATH}/webhook && \
            cd ${SRCPATH}/webhook && go get -d && go build -o /usr/local/bin/webhook && \
            apk del --purge build-deps && \
            rm -rf /var/cache/apk/* && \
            rm -rf ${GOPATH}

EXPOSE      9000

ENTRYPOINT  ["/usr/local/bin/webhook"]
