#!/bin/sh

if [ ! -f /opt/install.lock ]
then
  ARCHIVO=config/secrets.yml
  VARIABLE=secret_key_base
  echo "Generando archivo de configuracion ..."
  A=$(sed -ne "s/$VARIABLE://p" $ARCHIVO | sed -e "s/ //g")
  if [[ "$A" == "" ]]
  then
    sed -i 's@secret_key_base:.*@'"secret_key_base: $(bundle exec rake secret)"'@' $ARCHIVO
  fi
  if [ ! -z "$CONVERT_API_URL" ]
  then
    export CONVERT_API_URL=https://intranet.adsib.gob.bo/conversion-formatos
  fi
  chmod -R 777 ./config ./log ./tmp
  bundle exec rake assets:clobber
  bundle exec rake assets:precompile
  bundle exec rake db:migrate
  bundle exec rake db:seed
  bundle exec whenever -s 'environment=production' --update-crontab
  touch /opt/install.lock
fi

rails server -b 0.0.0.0 -e production
