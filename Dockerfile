# docker build . -t ckan && docker run -d -p 80:5000 --link db:db --link redis:redis --link solr:solr ckan

FROM ubuntu:16.04
LABEL MAINTAINER="abdulhakeem.shaibu@ehealthafrica.org"

ARG GITHUB_TOKEN

ENV CKAN_HOME /usr/lib/ckan/default
ENV CKAN_CONFIG /etc/ckan/default
ENV CKAN_STORAGE_PATH /var/lib/ckan

# Install required packages
RUN apt-get -q -y update && apt-get -q -y upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y install \
        python-dev \
        python-pip \
        python-virtualenv \
        libpq-dev \
        git-core \
        pwgen \
        gettext \
        cron \
        supervisor \
        libffi-dev \
        xvfb \
        wget \
    && apt-get -q clean

# setup ckan virtual env
RUN mkdir -p $CKAN_HOME $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    virtualenv $CKAN_HOME && \
    ln -s $CKAN_HOME/bin/pip /usr/local/bin/ckan-pip && \
    ln -s $CKAN_HOME/bin/paster /usr/local/bin/ckan-paster

# setup CKAN
ADD ./ckan_setup/ckan $CKAN_HOME/src/ckan/
RUN ckan-pip install --upgrade pip && \
    ckan-pip install setuptools==35.0 && \
    ckan-pip install --upgrade --no-cache-dir -r ${CKAN_HOME}/src/ckan/requirements.txt && \
    ckan-pip install -e ${CKAN_HOME}/src/ckan/ && \
    ln -s ${CKAN_HOME}/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini

# TMP-BUGFIX https://github.com/ckan/ckan/issues/3388
RUN ckan-pip install --upgrade --no-cache -r ${CKAN_HOME}/src/ckan/dev-requirements.txt

# install third-party extensions
RUN cd $CKAN_HOME/src && \
    ckan-pip install -e "git+https://github.com/datagovuk/ckanext-hierarchy.git#egg=ckanext-hierarchy" && \
    # install OAuth2Client (required by googleanalytics)
    ckan-pip install oauth2client && \
    ckan-pip install -e "git+https://github.com/ckan/ckanext-googleanalytics.git#egg=ckanext-googleanalytics" && \
    ckan-pip install -r $CKAN_HOME/src/ckanext-googleanalytics/requirements.txt && \
    # install Odata extension
    ckan-pip install -e "git+https://github.com/whythawk/ckanext-odata.git#egg=ckanext-odata" && \
    # install ckanext-scheming extension
    ckan-pip install -e "git+https://github.com/ckan/ckanext-scheming.git#egg=ckanext-scheming" && \
    ckan-pip install -r $CKAN_HOME/src/ckanext-scheming/requirements.txt && \
    # install ckan validation
    ckan-pip install -e "git+https://github.com/frictionlessdata/ckanext-validation.git#egg=ckanext-validation" && \
    ckan-pip install -r ${CKAN_HOME}/src/ckanext-validation/requirements.txt && \
    # install Geospatial View
    ckan-pip install ckanext-geoview

# add files required by google-analytics
COPY ./ckan_setup/conf/credentials.json.enc $CKAN_HOME/src/ckanext-googleanalytics/

# setup third-party tools & local scripts
# note AWS cli tools need to be installed outside virtualenv
ADD https://github.com/vishnubob/wait-for-it/raw/master/wait-for-it.sh /opt/ckan/wait-for-it.sh
RUN pip install awscli && \
    pip install supervisor-stdout && \
    ln -s ${CKAN_HOME}/src/ckan/conf/create_admin_user.sh /opt/ckan/create_admin_user.sh && \
    ln -s ${CKAN_HOME}/src/ckan/conf/ckan.ini.template ${CKAN_CONFIG}/ckan.ini.template

# setup eHA EOC Extensions
COPY ./src/extensions ${CKAN_HOME}/src/extensions/
RUN cd ${CKAN_HOME}/src/extensions/ && \
    # Install Gather 2 Integration
    ckan-pip install -e ${CKAN_HOME}/src/extensions/gather2_integration && \
    ckan-pip install -r ${CKAN_HOME}/src/extensions/gather2_integration/requirements.txt && \
    # Install EOC extension
    ckan-pip install -e ${CKAN_HOME}/src/extensions/ckanext-eoc && \
    ckan-pip install -r ${CKAN_HOME}/src/extensions/ckanext-eoc/requirements.txt

# setup supervisor & cron jobs
ADD ./ckan_setup/conf/supervisor /etc/supervisor/conf.d
ADD ./ckan_setup/conf/rebuild-index.sh /rebuild-index.sh
ADD ./ckan_setup/conf/rebuild-index-cron /etc/cron.d/rebuild-index-cron
ADD ./src/conf/supervisor-ckan-server.conf /etc/supervisor/conf.d/supervisor-ckan-server.conf

# grant scripts execution rights
RUN chmod +x /rebuild-index.sh && \
    chmod 0644 /etc/cron.d/rebuild-index-cron

# SetUp EntryPoint
COPY ./ckan_setup/conf/ckan-entrypoint.sh /
COPY ./ckan_setup/conf/entrypoint.sh /
RUN chmod +x /ckan-entrypoint.sh /opt/ckan/wait-for-it.sh /opt/ckan/create_admin_user.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Volumes
VOLUME ["/etc/ckan/default"]
VOLUME ["/var/lib/ckan"]
EXPOSE 5000
