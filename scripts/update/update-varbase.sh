#!/bin/bash
function clear_stdin(){
    while read -e -t 1; do : ; done
}

BASEDIR=$(PWD);
ERRORLOG=${BASEDIR}/.update-error-log;
DRUPALPATH='docroot';
if [ -d "${BASEDIR}/web" ]; then
  DRUPALPATH='web';
fi
DRUSH="${BASEDIR}/bin/drush8";
clear;
echo "$(tput setaf 4)";
cat << "EOF"
 __   __  _______  ______    __   __  _______
|  | |  ||   _   ||    _ |  |  | |  ||       |
|  |_|  ||  |_|  ||   | ||  |  | |  ||    _  |
|       ||       ||   |_||_ |  |_|  ||   |_| |
|       ||       ||    __  ||       ||    ___|
 |     | |   _   ||   |  | ||       ||   |
  |___|  |__| |__||___|  |_||_______||___|
EOF
echo "$(tput setaf 4)Varbase Updater$(tput sgr 0)";
echo "";
clear_stdin;
echo "$(tput setaf 1)Please choose your Drupal installation folder. Type the folder name or hit enter to choose the default one: ($DRUPALPATH): $(tput sgr 0)";
read drupalfolder;
if [ "$drupalfolder" ] ;then
  DRUPALPATH=$drupalfolder;
fi;

backup () {
  cd ${BASEDIR};
  rm -rf ${BASEDIR}/update_backups;
  mkdir -p ${BASEDIR}/update_backups
  tar --exclude='sites' -zcf ./update_backups/${DRUPALPATH}.tgz ./${DRUPALPATH}
  tar -zcf ./update_backups/vendor.tgz ./vendor
  cp ${BASEDIR}/composer.json ${BASEDIR}/update_backups/composer.json;
  cd ${BASEDIR}/${DRUPALPATH};
  ${DRUSH} sql-dump --result-file=${BASEDIR}/update_backups/db.sql 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo "$(tput setab 1)$(tput setaf 7)Error in creating a backup, exiting update process! Please check ${ERRORLOG} for more info.$(tput sgr 0)";
      cd ${BASEDIR};
      exit;
  fi
  mkdir -p ${BASEDIR}/update_backups/skip
  if [ -f ${BASEDIR}/scripts/update/.skip-update ]; then
    while read p; do
      if [ -d "${BASEDIR}/${DRUPALPATH}/modules/contrib/${p}" ]; then
        cp -r ${BASEDIR}/${DRUPALPATH}/modules/contrib/${p} ${BASEDIR}/update_backups/skip/;
      fi
    done < ${BASEDIR}/scripts/update/.skip-update
  fi
  cd ${BASEDIR};
}

revert_backup () {
  cd ${BASEDIR}
  rm -rf mv ${BASEDIR}/update_backups/sites
  mv ${BASEDIR}/${DRUPALPATH}/sites ${BASEDIR}/update_backups/
  rm -rf ${BASEDIR}/${DRUPALPATH}
  tar -xf ./update_backups/${DRUPALPATH}.tgz
  mv ${BASEDIR}/update_backups/sites ${BASEDIR}/${DRUPALPATH}/
  rm -rf ${BASEDIR}/vendor
  tar -xf ./update_backups/vendor.tgz
  cp ${BASEDIR}/update_backups/composer.json ${BASEDIR}/composer.json;
  cd ${BASEDIR}/${DRUPALPATH};
  $DRUSH sql-drop --yes 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  $DRUSH sql-cli < ${BASEDIR}/update_backups/db.sql --yes 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo "$(tput setab 1)$(tput setaf 7)Failed to restore the backup. Please check ${ERRORLOG} for more info. You can find the backup to restore it manually in ${BASEDIR}/update_backups$(tput sgr 0)";
      exit;
  fi
  cd ${BASEDIR};
  rm -rf ${BASEDIR}/update_backups;
}

exit_and_revert(){
  clear_stdin;
  echo "$(tput setaf 1)Would you like to abort the update process and restore the backup? (no): $(tput sgr 0)";
  read answer </dev/tty;
  if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo -e "$(tput setab 1)$(tput setaf 7)Going back in time and restoring the snapshot before the update process!$(tput sgr 0)";
    revert_backup;
    exit;
  fi
}

cleanup(){
  if [ -d ${BASEDIR}/vendor/drupal-composer/drupal-scaffold ]; then
    rm -rf ${BASEDIR}/vendor/drupal-composer/drupal-scaffold;
  fi
  if [ -d ${BASEDIR}/vendor/cweagans/composer-patches ]; then
    rm -rf ${BASEDIR}/vendor/cweagans/composer-patches;
  fi
  if [ -d ${BASEDIR}/${DRUPALPATH}/vendor ]; then
    rm -rf ${BASEDIR}/${DRUPALPATH}/vendor;
  fi
  if [ -f ${BASEDIR}/${DRUPALPATH}/composer.json ]; then
    rm -rf ${BASEDIR}/${DRUPALPATH}/composer.json;
  fi
  if [ -f ${BASEDIR}/${DRUPALPATH}/composer.lock ]; then
    rm -rf ${BASEDIR}/${DRUPALPATH}/composer.lock;
  fi
  if [ -f ${BASEDIR}/scripts/composer/ScriptHandler.php ]; then
    rm -rf ${BASEDIR}/scripts/composer/ScriptHandler.php;
  fi
  composer dump-autoload;
}

download_before_update(){
  if [ -f ${BASEDIR}/scripts/update/.download-before-update ]; then
    while read p; do
      echo -e "$(tput setaf 2)Downloading $p.$(tput sgr 0)";
      echo -e "$(tput setaf 2)Downloading $p.$(tput sgr 0)" >> ${ERRORLOG};
      $DRUSH up $p --pm-force --yes --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
      result="$?";
      if [ "$result" -ne 0 ]; then
          echo "$(tput setab 1)$(tput setaf 7)Error while downloading $p. Please check ${ERRORLOG} for more info.$(tput sgr 0)";
          exit_and_revert;
      fi
    done < ${BASEDIR}/scripts/update/.download-before-update
  fi
}

copy_after_update(){
  if [ -f ${BASEDIR}/scripts/update/.skip-update ]; then
    while read p; do
      if [ -d "${BASEDIR}/update_backups/skip/${p}" ]; then
        cp -r ${BASEDIR}/update_backups/skip/${p} ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
      fi
    done < ${BASEDIR}/scripts/update/.skip-update
  fi
}

enable_after_update(){
  if [ -f ${BASEDIR}/scripts/update/.enable-after-update ]; then
    while read p; do
      $DRUSH en $p --yes --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
      result="$?";
      if [ "$result" -ne 0 ]; then
          echo "$(tput setab 1)$(tput setaf 7)Error while enabling $p. Please check ${ERRORLOG} for more info.$(tput sgr 0)";
          exit_and_revert;
      fi
    done < ${BASEDIR}/scripts/update/.enable-after-update
  fi
}

echo "$(tput setab 2)";
php ${BASEDIR}/scripts/update/version-check.php current-message ${BASEDIR}/composer.json;
echo "$(tput sgr 0)";
echo "$(tput setaf 2)This command will guide you to update your Varbase project.$(tput sgr 0)";
echo "";
echo "$(tput setab 214)$(tput setaf 0)The update process will go through several tasks to update your Drupal core and modules. Please run this script on a development environment.$(tput sgr 0)";
echo -e "$(tput setaf 2) \t$(tput sgr 0)";
echo "$(tput setaf 2)The command will go through the following steps:$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 1. Backup your current installation (code and database)$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 2. Cleanup and update your composer.json to prepare for Varbase updates$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 3. Update Varbase using (composer update)$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 4. Enable some required modules before running Drupal database updates$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 5. Update entities (drush entity-updates)$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 5. Update Drupal database for latest changes (drush updatedb)$(tput sgr 0)";
echo -e "$(tput setaf 2) \t 6. Write log files and perform some cleanups$(tput sgr 0)";
echo -e "$(tput setaf 2) \t$(tput sgr 0)";
echo "$(tput setab 214)$(tput setaf 0)The update process will go through several tasks to update your Drupal core and modules. Please run this script on a development environment.$(tput sgr 0)";
clear_stdin;
if [ -d ${BASEDIR}/update_backups ]; then
  echo -e "$(tput setaf 1)What would you like to do?: $(tput sgr 0)";
  echo -e "$(tput setaf 1)- (u|update) To start the update process (default). $(tput sgr 0)"
  echo -e "$(tput setaf 1)- (r|revert) To revert the previews backup.$(tput sgr 0)";
  echo -e "$(tput setaf 1)- (e|exit) To exit.$(tput sgr 0)";
else
  echo -e "$(tput setaf 1)Do you want to start the update process? (yes): $(tput sgr 0)";
fi
read answer;
answer=${answer:-Yes}
if [ "$answer" != "${answer#[NnEe]}" ] ;then
  echo "$(tput setaf 2)Mission aborted.$(tput sgr 0)";
  exit;
elif [ "$answer" != "${answer#[Rr]}" ] ; then
  if [ -d ${BASEDIR}/update_backups ]; then
    echo "$(tput setaf 2)Reverting backup.$(tput sgr 0)";
    revert_backup;
    exit;
  else
     echo "$(tput setaf 2)Sorry there is no backup to revert!.$(tput sgr 0)";
     exit;
  fi
elif [ "$answer" != "${answer#[YyUu]}" ] ; then
  touch ${ERRORLOG};
  echo > ${ERRORLOG};
  echo -e "$(tput setaf 2)Preparing a backup snapshot before performing updates...$(tput sgr 0)";
  backup;
  echo -e "$(tput setaf 2)Preparing composer.json for Varbase updates...$(tput sgr 0)";
  echo -e "$(tput setaf 2)Preparing composer.json for Varbase updates...$(tput sgr 0)" >> ${ERRORLOG};
  cleanup;
  composer run-script varbase-composer-generate > ${BASEDIR}/composer.new.json;
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)There was and error while preparing composer.json for Varbase updates. Please check ${ERRORLOG} for more information.$(tput sgr 0)";
      echo -e "$(tput setab 1)$(tput setaf 7)If you are running Varbase 8.x-4.x or 8.x-5.x version, make sure to update varbase-project using the update command: $(tput sgr 0)";
      echo -e "$(tput setaf 2)wget -O - -q https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/scripts/update/update.php | php$(tput sgr 0)";
      exit_and_revert;
  fi
  mv ${BASEDIR}/composer.new.json ${BASEDIR}/composer.json;
  clear_stdin;
  echo "$(tput setaf 4)composer.json has been updated. Now is your chance to perform any manual changes. Please do your changes (if any) then press enter to continue... $(tput sgr 0)";
  read answer;

  echo -e "$(tput setaf 2)Updating Varbase...$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating Varbase...$(tput sgr 0)" >> ${ERRORLOG};
  composer update 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)There was and error while updating Varbase to the latest version. Please check ${ERRORLOG} for more information.$(tput sgr 0)";
      exit_and_revert;
  fi

  echo -e "$(tput setaf 2)Creating a log of all failed patches, please check failed-patches.txt after the update process finishes...$(tput sgr 0)";
  grep -i "Could not apply patch! Skipping" ${BASEDIR}/.update-error-log > failed-patches.txt
  copy_after_update;
  cd ${BASEDIR}/${DRUPALPATH};
  $DRUSH cr --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)Something went wrong while rebuilding the cache (drush cr), this might cause the update to fail.$(tput sgr 0)";
      exit_and_revert;
  fi
  echo -e "$(tput setaf 2)Enabling new required modules for the latest Varbase version...$(tput sgr 0)";
  echo -e "$(tput setaf 2)Enabling new required modules for the latest Varbase version...$(tput sgr 0)" >> ${ERRORLOG};
  enable_after_update;

  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)" >> ${ERRORLOG};
  $DRUSH  updb --yes --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)There was and error while updating Drupal core. Please check ${ERRORLOG} for more information.$(tput sgr 0)";
      exit_and_revert;
  fi

  echo "$(tput setaf 2)Hoya! Updates are now done. We will add a link in the near future for here to link to common issues appearing after updates and how to fix them.$(tput sgr 0)";
  echo "$(tput setaf 2)Hoya! Updates are now done. We will add a link in the near future for here to link to common issues appearing after updates and how to fix them.$(tput sgr 0)" >> ${ERRORLOG};
  php ${BASEDIR}/scripts/update/version-check.php next-message ${BASEDIR}/composer.json;
  cd ${BASEDIR};
else
  echo "$(tput setaf 2)Unrecognized option, exiting...$(tput sgr 0)";
  exit;
fi
