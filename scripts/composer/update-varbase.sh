#!/bin/bash

BASEDIR=$(PWD);
DRUPALPATH='docroot';
if [ -d "${BASEDIR}/web" ]; then
  DRUPALPATH='web';
fi
DRUSH="${BASEDIR}/bin/drush8";
echo "$(tput setaf 1)Please enter your drupal installation folder ($DRUPALPATH): $(tput sgr 0)";
read drupalfolder;

if [ "$drupalfolder" ] ;then
  DRUPALPATH=$drupalfolder;
fi;

backup () {
  echo > ${BASEDIR}/.update-logs;
  mkdir -p ${BASEDIR}/update_backups/${DRUPALPATH};
  mkdir -p ${BASEDIR}/update_backups/database;
  rsync -a ${BASEDIR}/${DRUPALPATH} ${BASEDIR}/update_backups --exclude sites
  cp -r ${BASEDIR}/vendor ${BASEDIR}/update_backups/;
  echo ../bin/drush8 > "${BASEDIR}/${DRUPALPATH}/.drush-use";
  $DRUSH sql-dump --result-file=${BASEDIR}/update_backups/database/db.sql --yes  >> ${BASEDIR}/.update-logs 2>&1;
  exception=$(grep -ir 'Drush command terminated abnormally due to an unrecoverable error.' ${BASEDIR}/.update-logs);
  if [ "$exception" ]; then
    return -1;
  else
    return 0;
  fi
}

revert_backup () {
  echo > ${BASEDIR}/.update-logs;
  mv ${BASEDIR}/${DRUPALPATH}/sites ${BASEDIR}/update_backups/sites;
  rm -rf ${BASEDIR}/${DRUPALPATH}/*
  mv ${BASEDIR}/update_backups/sites ${BASEDIR}/${DRUPALPATH}/sites;
  rsync -a ${BASEDIR}/update_backups/${DRUPALPATH}/ ${BASEDIR}/${DRUPALPATH}
  rm -rf ${BASEDIR}/vendor/*
  cp -r ${BASEDIR}/update_backups/vendor ${BASEDIR}/;
  echo ../bin/drush8 > "${BASEDIR}/${DRUPALPATH}/.drush-use";
  $DRUSH sql-cli < ${BASEDIR}/update_backups/database/db.sql --yes >> ${BASEDIR}/.update-logs 2>&1;
  exception=$(grep -ir 'Drush command terminated abnormally due to an unrecoverable error.' ${BASEDIR}/.update-logs);
  if [ "$exception" ]; then
    return -1;
  else
    return 0;
  fi
}

remove_drush(){
  echo ../bin/drush8 > ${BASEDIR}/${DRUPALPATH}/.drush-use;
  if [ -d "${BASEDIR}/vendor/drush" ]; then
    if [ -d "${BASEDIR}/vendor/drush_b" ]; then
      rm -rf ${BASEDIR}/vendor/drush_b;
    fi
    mv ${BASEDIR}/vendor/drush ${BASEDIR}/vendor/drush_b;
  fi
}

reset_drush(){
  rm ${BASEDIR}/${DRUPALPATH}/.drush-use;
  if [ -d "${BASEDIR}/vendor/drush" ]; then
    if [ -d "${BASEDIR}/vendor/drush_b" ]; then
          rm -rf ${BASEDIR}/vendor/drush_b;
    fi
  else
    if [ -d "${BASEDIR}/vendor/drush_b" ]; then
      mv ${BASEDIR}/vendor/drush_b ${BASEDIR}/vendor/drush;
    fi
  fi
}

download_before_update(){
  if [ -f ${BASEDIR}/.download-before-update ]; then
    while read p; do
      $DRUSH dl $p --pm-force --yes --strict=0 >> ${BASEDIR}/.update-logs 2>&1;
    done < ${BASEDIR}/.download-before-update
  fi
}

copy_after_update(){
  if [ -f ${BASEDIR}/.skip-update ]; then
    while read p; do
      if [ -d "${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/${p}" ]; then
        cp -r ${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/${p} ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
      fi
    done < ${BASEDIR}/.skip-update
  fi
}

enable_after_update(){
  if [ -f ${BASEDIR}/.enable-after-update ]; then
    while read p; do
      $DRUSH  en $p --yes --strict=0 >> ${BASEDIR}/.update-logs 2>&1;
    done < ${BASEDIR}/.enable-after-update
  fi
}

echo "";
echo "$(tput setaf 4)Welcome to varbase updater:$(tput sgr 0)";
echo "";
echo "$(tput setaf 2)This command will guide you to update to the latest varbase$(tput sgr 0)";
echo "";
echo "$(tput setab 214)$(tput setaf 0)This proccess will update your drupal core & modules so please run it on development environment before running on live environment$(tput sgr 0)";
echo "$(tput setaf 2)The command will go through the follwing steps:$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 1. Update drupal core to latest (drush up drupal).$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 2. Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 3. Update varbase to latest using (composer update).$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 4. Enable some required modules for latest varbase.$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 5. Updating the database for latest changes (drush updb).$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 6. Cleaning up.$(tput sgr 0)";
echo "$(tput setab 214)$(tput setaf 0)This proccess will update your drupal core & modules so please run it on development environment before running on live environment$(tput sgr 0)";
echo "$(tput setaf 1)Do you want to start the update process? (yes|no): $(tput sgr 0)";
read answer;
if [ "$answer" != "${answer#[Nn]}" ] ;then
  echo "$(tput setaf 2)Exiting update process, Thank you.$(tput sgr 0)"
else

  echo -e "$(tput setaf 2)Preparing backups.$(tput sgr 0)";
  backup;

  echo -e "$(tput setaf 2)Preparing for update.$(tput sgr 0)";
  remove_drush;
  touch ${BASEDIR}/.update-logs;
  echo > ${BASEDIR}/.update-logs;

  echo -e "$(tput setaf 2)Updating drupal core to latest.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating drupal core to latest.$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  cd ${BASEDIR}/${DRUPALPATH};
  download_before_update;
  $DRUSH up drupal --pm-force --yes --strict=0 >> ${BASEDIR}/.update-logs 2>&1;
  exception=$(grep -ir 'Drush command terminated abnormally due to an unrecoverable error.' ${BASEDIR}/.update-logs);
  if [ "$exception" ]; then
    echo -e "$(tput setaf 1)There was and error while updating drupal core please check .update-logs file for more information$(tput sgr 0)";
    echo -e "$(tput setaf 2)Reverting Backup!.$(tput sgr 0)";
    revert_backup;
    exit;
  fi
  cd "${BASEDIR}";
  echo -e "$(tput setaf 2)Updating drupal core is done.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating drupal core is done.$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  exit;
  echo -e "$(tput setaf 2)Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  composer run-script varbase-composer-generate > ${BASEDIR}/composer.new.json;
  cp ${BASEDIR}/composer.json ${BASEDIR}/update_backups/composer.json.b;
  mv ${BASEDIR}/composer.new.json ${BASEDIR}/composer.json;

  echo -e "$(tput setaf 2)Updating varbase to latest.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating varbase to latest.$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  composer update;
  composer update;
  composer drupal-scaffold;

  copy_after_update;

  cd ${BASEDIR}/${DRUPALPATH};
  remove_drush;
  $DRUSH  cr --strict=0 >> ${BASEDIR}/.update-logs 2>&1;

  echo -e "$(tput setaf 2)Enable some required modules for latest varbase.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Enable some required modules for latest varbase.$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  enable_after_update;

  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  $DRUSH  updb --yes --strict=0 >> ${BASEDIR}/.update-logs 2>&1;

  exception=$(grep -ir 'Drush command terminated abnormally due to an unrecoverable error.' ${BASEDIR}/.update-logs);
  if [ "$exception" ]; then
    echo -e "$(tput setaf 1)There was and error while updating drupal core please check .update-logs file for more information$(tput sgr 0)";
    echo -e "$(tput setaf 2)Reverting Backup!.$(tput sgr 0)";
    revert_backup;
    exit;
  fi

  echo "$(tput setaf 2)Update is done!$(tput sgr 0)";
  echo "$(tput setaf 2)Update is done!$(tput sgr 0)" >> ${BASEDIR}/.update-logs;
  reset_drush;
fi
