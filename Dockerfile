FROM ruby:2.4.1-alpine
MAINTAINER devops@signiant.com

# Add our bldmgr user
ENV BUILD_USER bldmgr
ENV BUILD_PASS bldmgr
ENV BUILD_USER_ID 10012
ENV BUILD_USER_GROUP users
#ENV BUILD_DOCKER_GROUP docker
#ENV BUILD_DOCKER_GROUP_ID 1001

COPY apk.std-packages.list /tmp/apk.std-packages.list
COPY apk.edge-packages.list /tmp/apk.edge-packages.list

RUN chmod +r /tmp/apk.std-packages.list && \
    chmod +r /tmp/apk.edge-packages.list && \
    apk --update add `cat /tmp/apk.std-packages.list` && \
    apk add --update-cache `cat /tmp/apk.edge-packages.list` \
    --repository http://dl-3.alpinelinux.org/alpine/edge/main/ \
    --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ \
    --repository http://dl-3.alpinelinux.org/alpine/edge/community/ --allow-untrusted && \
    rm -rf /var/cache/apk/*

#    apk add dos2unix --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
#    apk add curl --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \    

#RUN pip install python-jenkins docker python-jenkins maestroops && pip show maestroops

RUN adduser -D $BUILD_USER -u $BUILD_USER_ID -s /bin/sh -G $BUILD_USER_GROUP && \
    chown -R $BUILD_USER:$BUILD_USER_GROUP /home/$BUILD_USER && \
    echo "$BUILD_USER:$BUILD_PASS" | chpasswd

RUN /usr/bin/ssh-keygen -A

RUN set -x && \
    echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "AllowGroups ${BUILD_USER_GROUP}" >> /etc/ssh/sshd_config

# Comment these lines to disable sudo
RUN apk --update add sudo && \
    rm -rf /var/cache/apk/*
ADD /sudoers.txt /etc/sudoers
RUN chmod 440 /etc/sudoers

#setup jenkins dir
RUN mkdir -p /var/lib/jenkins \
    && chown -R $BUILD_USER:$BUILD_USER_GROUP /var/lib/jenkins

EXPOSE 22

# This entry will either run this container as a jenkins slave or just start SSHD
# If we're using the slave-on-demand, we start with SSH (the default)

# Default Jenkins Slave Name
ENV SLAVE_ID JAVA_NODE
ENV SLAVE_OS Linux

ADD start.sh /
RUN chmod 777 /start.sh

CMD ["sh", "/start.sh"]
