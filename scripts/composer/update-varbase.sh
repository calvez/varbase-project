#!/bin/bash
BASEDIR=$(PWD);
DRUPALPATH='docroot';
if [ -d "${PWD}/web" ]; then
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
  cp -r ${BASEDIR}/vendor ${BASEDIR}/update_backups/vendor;
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
  backup
  echo -e "$(tput setaf 2)Preparing for update.$(tput sgr 0)";
  echo ../bin/drush8 > ${BASEDIR}/${DRUPALPATH}/.drush-use;
  mv ${BASEDIR}/vendor/drush ${BASEDIR}/vendor/drush_b;
  touch ${BASEDIR}/.update-logs;
  echo > ${BASEDIR}/.update-logs;
  echo -e "$(tput setaf 2)Updating drupal core to latest.$(tput sgr 0)";
  cd "${PWD}/${DRUPALPATH}";
  $DRUSH dl page_manager --pm-force --yes --strict=0 >> ${BASEDIR}/.update-logs 2>&1;
  $DRUSH up drupal --pm-force --yes --strict=0 >> ${BASEDIR}/.update-logs 2>&1;
  exception=$(grep -ir 'Drush command terminated abnormally due to an unrecoverable error.' ${BASEDIR}/.update-logs);
  if [ "$exception" ]; then
    echo -e "$(tput setaf 1)There was and error while updating drupal core.$(tput sgr 0)";
    echo -e "$(tput setaf 2)Reverting Backup!.$(tput sgr 0)";
    revert_backup;
    exit;
  fi
  cd "${BASEDIR}";
  echo -e "$(tput setaf 2)Updating drupal core is done.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)";
  composer run-script varbase-composer-generate > ${PWD}/composer.new.json;
  cp ${PWD}/composer.json ${PWD}/update_backups/composer.json.b;
  mv ${PWD}/composer.new.json ${PWD}/composer.json;
  echo -e "$(tput setaf 2)Update varbase to latest.$(tput sgr 0)";
  composer update;
  composer update;
  composer drupal-scaffold;
  cp -r ${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/media_entity_document ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
  cp -r ${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/media_entity_image ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
  cp -r ${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/login_destination ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
  cp -r ${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/node_edit_protection ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
  cd ${BASEDIR}/${DRUPALPATH};
  echo ../bin/drush8 > "${BASEDIR}/${DRUPALPATH}/.drush-use";
  rm -rf ${BASEDIR}/vendor/drush_b;
  mv ${BASEDIR}/vendor/drush ${BASEDIR}/vendor/drush_b;
  $DRUSH cr >> ${BASEDIR}/.update-logs 2>&1;
  echo -e "$(tput setaf 2)Enable some required modules for latest varbase.$(tput sgr 0)";
  $DRUSH en entity_browser_generic_embed --yes >> ${BASEDIR}/.update-logs 2>&1;
  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)";
  $DRUSH updb --yes >> ${BASEDIR}/.update-logs 2>&1;
  exception=$(grep -ir 'Drush command terminated abnormally due to an unrecoverable error.' ${BASEDIR}/.update-logs);
  if [ "$exception" ]; then
    echo -e "$(tput setaf 1)There was and error while updating drupal core.$(tput sgr 0)";
    echo -e "$(tput setaf 2)Reverting Backup!.$(tput sgr 0)";
    revert_backup;
    exit;
  fi
  echo "$(tput setaf 2)Update is done!$(tput sgr 0)";
  mv ${BASEDIR}/vendor/drush_b ${BASEDIR}/vendor/drush;
  echo  > ${BASEDIR}/${DRUPALPATH}/.drush-use;
fi
