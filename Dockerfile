FROM node:8-alpine
MAINTAINER devops@signiant.com

RUN apk --update add device-mapper device-mapper-libs device-mapper-event-libs

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

#RUN pip install python-jenkins docker python-jenkins maestroops && pip show maestroops
RUN pip install docker-compose

# Add our bldmgr user
ENV BUILD_USER bldmgr
ENV BUILD_PASS bldmgr
ENV BUILD_USER_ID 10012
ENV BUILD_USER_GROUP users
ENV BUILD_DOCKER_GROUP docker
ENV BUILD_DOCKER_GROUP_ID 1001

#RUN groupadd -g $BUILD_DOCKER_GROUP_ID $BUILD_DOCKER_GROUP \
#  && adduser -u $BUILD_USER_ID -g $BUILD_USER_GROUP $BUILD_USER \
#  && echo $BUILD_USER:$BUILD_PASS |chpasswd \
#  && usermod -a -G $BUILD_DOCKER_GROUP $BUILD_USER

RUN addgroup -g $BUILD_DOCKER_GROUP_ID $BUILD_DOCKER_GROUP \
  && adduser -D $BUILD_USER -u $BUILD_USER_ID -s /bin/bash -G $BUILD_USER_GROUP \
  &&  chown -R $BUILD_USER:$BUILD_USER_GROUP /home/$BUILD_USER \
  &&  echo "$BUILD_USER:$BUILD_PASS" | chpasswd \
  && usermod -a -G $BUILD_DOCKER_GROUP $BUILD_USER

# Install Java
ENV JAVA_VERSION 7u79
ENV BUILD_VERSION b15
ENV JAVA_HOME /usr/java/latest

# Downloading Oracle Java
#RUN wget --no-verbose --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
#"http://download.oracle.com/otn-pub/java/jdk/$JAVA_VERSION-$BUILD_VERSION/jdk-$JAVA_VERSION-linux-x64.rpm" -O /tmp/jdk-7-linux-x64.rpm \
#  && yum -y install /tmp/jdk-7-linux-x64.rpm \
#  && rm -f /tmp/jdk-7-linux-x64.rpm \
#  && alternatives --install /usr/bin/java jar /usr/java/latest/bin/java 200000 \
#  && alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000 \
#  && alternatives --install /usr/bin/javac javac /usr/java/latest/bin/javac 200000

# Setup build environment / tools
ENV NPM_VERSION latest-2
ENV FINDBUGS_VERSION 2.0.3
ENV ANT_VERSION 1.9.6
ENV ANT_HOME /usr/local/apache-ant-${ANT_VERSION}

# Update npm
# && Install npm packages needed by builds
#  -- We have to use the fixed version of grunt-connect-proxy otherwise we get fatal socket hang up errors
# && Install findbugs
# && Install ant
# && Install link to ant
RUN npm version && npm install -g npm@${NPM_VERSION} && npm version \
  && npm install -g bower grunt@0.4 grunt-cli grunt-connect-proxy@0.1.10 n \
  && curl -fSLO http://downloads.sourceforge.net/project/findbugs/findbugs/$FINDBUGS_VERSION/findbugs-$FINDBUGS_VERSION.tar.gz && \
    tar xzf findbugs-$FINDBUGS_VERSION.tar.gz -C /home/$BUILD_USER  && \
    rm findbugs-$FINDBUGS_VERSION.tar.gz \
  && wget --no-verbose http://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz && \
    tar -xzf apache-ant-${ANT_VERSION}-bin.tar.gz && \
    mv apache-ant-${ANT_VERSION} /usr/local/apache-ant-${ANT_VERSION} && \
    rm apache-ant-${ANT_VERSION}-bin.tar.gz \
  && ln -s ${ANT_HOME}/bin/ant /usr/bin/ant

#  && update-alternatives --install /usr/bin/ant ant ${ANT_HOME}/bin/ant 20000

RUN chmod -R +r /usr/local/lib/node_modules/npm/node_modules/*

# Install our required ant libs
COPY ant-libs/*.jar ${ANT_HOME}/lib/
RUN chmod 644 ${ANT_HOME}/lib/*.jar \
  && sh -c 'echo ANT_HOME=/usr/local/apache-ant-${ANT_VERSION} >> /etc/environment'

# Create the folder we use for Jenkins workspaces across all nodes
RUN mkdir -p /var/lib/jenkins \
  && chown -R $BUILD_USER:$BUILD_USER_GROUP /var/lib/jenkins

# Add in our common jenkins node tools for bldmgr
COPY jenkins_nodes /home/$BUILD_USER/jenkins_nodes

# Comment these lines to disable sudo
RUN apk --update add sudo && \
    rm -rf /var/cache/apk/*
ADD /sudoers.txt /etc/sudoers
RUN chmod 440 /etc/sudoers

# Make our build user require no tty
# && Add user to sudoers with NOPASSWD
# && Install and configure SSHD (needed by the Jenkins slave-on-demand plugin)
# RUN echo "Defaults:$BUILD_USER !requiretty" >> /etc/sudoers \
#   && echo "$BUILD_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
RUN ssh-keygen -q -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key \
  && ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key \
  && ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key \
  # && sed -ri 's/session    required     pam_loginuid.so/#session    required     pam_loginuid.so/g' /etc/pam.d/sshd \
  # && sed -ri 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config \
  && mkdir -p /home/$BUILD_USER/.ssh \
  && chown -R $BUILD_USER:$BUILD_USER_GROUP /home/$BUILD_USER \
  && chmod 700 /home/$BUILD_USER/.ssh

# RUN /usr/bin/ssh-keygen -A

RUN set -x && \
    echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "AllowGroups ${BUILD_USER_GROUP}" >> /etc/ssh/sshd_config \
    && sed -ri 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config


# # Comment these lines to disable sudo
# RUN apk --update add sudo && \
#     rm -rf /var/cache/apk/*
# ADD /sudoers.txt /etc/sudoers
# RUN chmod 440 /etc/sudoers

#setup jenkins dir
#RUN mkdir -p /var/lib/jenkins \
#    && chown -R $BUILD_USER:$BUILD_USER_GROUP /var/lib/jenkins

EXPOSE 22

# This entry will either run this container as a jenkins slave or just start SSHD
# If we're using the slave-on-demand, we start with SSH (the default)

# Default Jenkins Slave Name
ENV SLAVE_ID JAVA_NODE
ENV SLAVE_OS Linux

ADD start.sh /
RUN chmod 777 /start.sh

CMD ["sh", "/start.sh"]
