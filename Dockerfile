FROM docker:latest

MAINTAINER Xadozuk <xadozuk@gmail.com>

RUN apk --no-cache add jq bash 

COPY vbackup.sh /vbackup
COPY daily /etc/periodic/daily

VOLUME ["/backups"]

CMD ["/usr/sbin/crond", "-f"]
