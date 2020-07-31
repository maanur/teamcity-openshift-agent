FROM --platform=amd64 registry.access.redhat.com/ubi8/ubi-minimal

ARG TEAMCITY_URL=http://84.201.174.166:8111

SHELL [ "/bin/bash", "-c" ]

# Install JRE and build tools
RUN microdnf install java-1.8.0-openjdk-headless hostname git curl tar unzip && \
    microdnf clean all
ENV JRE_HOME /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.262.b10-0.el8_2.x86_64/jre

COPY run-agent.sh /run-agent.sh
RUN curl -L -O ${TEAMCITY_URL}/update/buildAgentFull.zip && \
    unzip buildAgentFull.zip \
     -x *windows* \
     -x *macosx* \
     -x *solaris* \
     -x *.bat \
     -x *linux-x86-32* \
     -x *linux-ppc-64* \
     -d /opt/buildagent && \
    rm buildAgentFull.zip && \
    rm /opt/buildagent/conf/buildAgent.dist.properties && \
    printf "\
    # Required Agent Properties
    serverUrl=${TEAMCITY_URL}/ \n\
    name= \n\
    workDir=../work \n\
    tempDir=../temp \n\
    systemDir=../system \n\
    # Optional Agent Properties 
    authorizationToken= \n\
    # Custom Agent Properties
    teamcity.tool.curl=/usr/bin/curl \n\
    " > /opt/buildagent/conf/buildAgent.properties && \
    useradd -m buildagent && \
    chmod +x /opt/buildagent/bin/*.sh && \
    chmod +x /run-agent.sh && \
    mkdir -p /data/teamcity_agent/conf && \
    mkdir -p /opt/buildagent/work && \
    mkdir -p /opt/buildagent/system && \
    mkdir -p /opt/buildagent/temp && \
    mkdir -p /opt/buildagent/logs && \
    mkdir -p /opt/buildagent/tools && \
    chown -R buildagent:root /opt/buildagent && \
    chown buildagent:root /run-agent.sh && \
    chmod +x /opt/buildagent/bin/*.sh && \
    chmod -R g+u /opt && sync
ENV HOME=/opt/buildagent CONFIG_FILE=/opt/buildagent/conf/buildAgent.properties

# Add 'oc' tool
ARG OC_TAR_URL=https://downloads-openshift-console.apps-crc.testing/amd64/linux/oc.tar
RUN curl -k ${OC_TAR_URL} | tar -x -C /usr/local/bin && \
    chmod a+x /usr/local/bin/oc && \
    printf "\
    teamcity.tool.oc=/usr/local/bin/oc \n\
    " >> $CONFIG_FILE

# Add 'openssl' tool
RUN microdnf install openssl && \
    microdnf clean all && \
    printf "\
    teamcity.tool.openssl=/usr/bin/openssl \n\
    " >> $CONFIG_FILE

# Add 'yq' tool
ARG YQ_BINARY_URL=https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64
RUN curl -L -o /usr/local/bin/yq ${YQ_BINARY_URL} && \
    chmod a+x /usr/local/bin/yq && \
    printf "\
    teamcity.tool.yq=/usr/local/bin/yq \n\
    " >> $CONFIG_FILE

WORKDIR /opt/buildagent
USER buildagent
CMD [ "/run-agent.sh", "start" ]
