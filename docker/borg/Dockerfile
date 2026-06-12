FROM alpine:3.23

RUN apk add --no-cache borgbackup openssh-client jq && \
    borg --version

RUN adduser -D -h /home/borg borg

USER borg
WORKDIR /home/borg

ENTRYPOINT ["borg"]
CMD ["--help"]
