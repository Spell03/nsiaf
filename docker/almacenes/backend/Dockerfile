FROM ruby:2.3.6

LABEL maintainer="djimenez@agetic.gob.bo"
LABEL version="1.0.0"
LABEL description="Backend para el sistema de activos y almacenes NSIAF"

ENV DOMINIO nsiaf
ENV RAILS_SERVE_STATIC_FILES enabled
ENV RAILS_ENV production

RUN mkdir -p /opt/nsiaf
WORKDIR /opt/nsiaf
RUN echo "America/La_Paz" | tee /etc/timezone; dpkg-reconfigure -f noniteractive tzdata; curl -sL https://deb.nodesource.com/setup_8.x | bash -; apt-get install -y nodejs imagemagick libmagickwand-dev cron; wget -O /tmp/wkhtmltopdf.tar.xz -c https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.3/wkhtmltox-0.12.3_linux-generic-amd64.tar.xz; tar -xf /tmp/wkhtmltopdf.tar.xz -C /opt/; ln -s /usr/bin/nodejs /usr/bin/node; npm install -g yarn@1.5.1; wget --no-check-certificate -O /tmp/nsiaf.tar.gz -c https://gitlab.geo.gob.bo/adsib/nsiaf/repository/archive.tar.gz?ref=agetic-mysql; tar -xf /tmp/nsiaf.tar.gz -C /opt/nsiaf --strip-components 1; bundle install --deployment --without development test; yarn install; mkdir log; mkdir tmp; touch log/production.log; apt-get remove -y --purge curl wget g++ gcc make automake openssh-client mercurial; apt-get autoremove --purge -y; apt-get autoclean --dry-run; rm -rf /tmp/*

COPY database.yml secrets.yml config/
COPY run.sh /opt/run.sh

VOLUME ["/opt/nsiaf/log"]
EXPOSE 3000
ENTRYPOINT /opt/run.sh