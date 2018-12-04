#!/bin/bash
BASEDIR=$(PWD);
ERRORLOG=${BASEDIR}/.update-error-log;
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
  rm -rf ${BASEDIR}/update_backups;
  mkdir -p ${BASEDIR}/update_backups/${DRUPALPATH};
  mkdir -p ${BASEDIR}/update_backups/database;
  cp -r ${BASEDIR}/${DRUPALPATH} ${BASEDIR}/update_backups/;
  cp -r ${BASEDIR}/vendor ${BASEDIR}/update_backups/;
  cp ${BASEDIR}/composer.json ${BASEDIR}/update_backups/composer.json;
  echo ${DRUSH} > "${BASEDIR}/${DRUPALPATH}/.drush-use";
  remove_drush;
  echo ${DRUSH} > "${BASEDIR}/${DRUPALPATH}/.drush-use";
  cd ${BASEDIR}/${DRUPALPATH};
  ${DRUSH} sql-dump --result-file=${BASEDIR}/update_backups/database/db.sql 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo "$(tput setab 1)$(tput setaf 7)Backup failed exiting update process pelase check ${ERRORLOG} for more info$(tput sgr 0)";
      cd ${BASEDIR};
      reset_drush;
      exit;
  fi
  cd ${BASEDIR};
}

revert_backup () {
  cd ${BASEDIR}
  rm -rf ${BASEDIR}/${DRUPALPATH}
  cp -r ${BASEDIR}/update_backups/${DRUPALPATH} ${BASEDIR}/
  rm -rf ${BASEDIR}/vendor/*
  cp -r ${BASEDIR}/update_backups/vendor ${BASEDIR}/;
  cp ${BASEDIR}/update_backups/composer.json ${BASEDIR}/composer.json;
  echo ${BASEDIR}/bin/drush8 > "${BASEDIR}/${DRUPALPATH}/.drush-use";
  remove_drush;
  cd ${BASEDIR}/${DRUPALPATH};
  $DRUSH sql-drop --yes 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  $DRUSH sql-cli < ${BASEDIR}/update_backups/database/db.sql --yes 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo "$(tput setab 1)$(tput setaf 7)Backup revert failed pelase check ${ERRORLOG} for more info, you can find the backups under ${BASEDIR}/update_backups.$(tput sgr 0)";
      reset_drush;
      exit;
  fi
  cd ${BASEDIR};
  reset_drush;
}

remove_drush(){
  echo ${BASEDIR}/bin/drush8 > ${BASEDIR}/${DRUPALPATH}/.drush-use;
  if [ -d "${BASEDIR}/vendor/drush" ]; then
    if [ -d "${BASEDIR}/vendor/drush_b" ]; then
      rm -rf ${BASEDIR}/vendor/drush_b;
    fi
    mv ${BASEDIR}/vendor/drush ${BASEDIR}/vendor/drush_b;
  fi
  composer dump-autoload;
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
          echo "$(tput setab 1)$(tput setaf 7)Error while downloading $p, reverting your site back. Please check ${ERRORLOG} for more info.$(tput sgr 0)";
          revert_backup;
          exit;
      fi
    done < ${BASEDIR}/scripts/update/.download-before-update
  fi
}

copy_after_update(){
  if [ -f ${BASEDIR}/scripts/update/.skip-update ]; then
    while read p; do
      if [ -d "${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/${p}" ]; then
        cp -r ${BASEDIR}/update_backups/${DRUPALPATH}/modules/contrib/${p} ${BASEDIR}/${DRUPALPATH}/modules/contrib/;
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
          echo "$(tput setab 1)$(tput setaf 7)Error while enabling $p, reverting your site back. Please check ${ERRORLOG} for more info.$(tput sgr 0)";
          revert_backup;
          exit;
      fi
    done < ${BASEDIR}/scripts/update/.enable-after-update
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
  touch ${ERRORLOG};
  echo > ${ERRORLOG};
  echo -e "$(tput setaf 2)Preparing backups.$(tput sgr 0)";
  backup;
  echo -e "$(tput setaf 2)Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)" >> ${ERRORLOG};
  if [ -d ${BASEDIR}/vendor/drupal-composer ]; then
    rm -rf ${BASEDIR}/vendor/drupal-composer;
  fi
  if [ -d ${BASEDIR}/${DRUPALPATH}/vendor ]; then
    rm -rf ${BASEDIR}/${DRUPALPATH}/vendor;
  fi
  if [ -f ${BASEDIR}/${DRUPALPATH}/composer.json ]; then
    rm -rf ${BASEDIR}/${DRUPALPATH}/composer.json;
  fi
  composer dump-autoload;
  composer run-script varbase-composer-generate > ${BASEDIR}/composer.new.json;
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)There was and error while Cleanup & Update composer.json please check ${ERRORLOG} file for more information$(tput sgr 0)";
      echo -e "$(tput setab 1)$(tput setaf 7)If you are on 4.x/5.x make sure to update varbase-project using the update command: $(tput sgr 0)";
      echo -e "$(tput setaf 2)wget -O - -q https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/scripts/update/update.php | php$(tput sgr 0)";
      echo -e "$(tput setab 2)$(tput setaf 7)Reverting Backup!.$(tput sgr 0)";
      revert_backup;
      exit;
  fi
  mv ${BASEDIR}/composer.new.json ${BASEDIR}/composer.json;
  cd ${BASEDIR}/${DRUPALPATH};
  echo -e "$(tput setaf 2)Downloading needed modules before update.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Downloading needed modules before update.$(tput sgr 0)" >> ${ERRORLOG};
  download_before_update;
  # $DRUSH up drupal --pm-force --yes --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  # result="$?";
  # if [ "$result" -ne 0 ]; then
  #     echo -e "$(tput setab 1)$(tput setaf 7)There was and error while updating drupal core please check ${ERRORLOG} file for more information$(tput sgr 0)";
  #     echo -e "$(tput setab 1)$(tput setaf 7)Reverting Backup!.$(tput sgr 0)";
  #     revert_backup;
  #     exit;
  # fi
  cd "${BASEDIR}";
  echo -e "$(tput setaf 2)Updating varbase.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating varbase.$(tput sgr 0)" >> ${ERRORLOG};
  composer update 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)There was and error while Updating varbase to latest please check ${ERRORLOG} file for more information$(tput sgr 0)";
      echo -e "$(tput setab 1)$(tput setaf 7)Reverting Backup!.$(tput sgr 0)";
      revert_backup;
      exit;
  fi

  copy_after_update;

  remove_drush;
  cd ${BASEDIR}/${DRUPALPATH};
  $DRUSH cr --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)Something went wrong while rebuilding the cache (drush cr), this might cause the update to fail.$(tput sgr 0)";
      echo -e "$(tput setab 1)$(tput setaf 7)We will continue the update anyway, as it might get solved while applying the new database updates.$(tput sgr 0)";
  fi
  echo -e "$(tput setaf 2)Enable some required modules for latest varbase.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Enable some required modules for latest varbase.$(tput sgr 0)" >> ${ERRORLOG};
  enable_after_update;

  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)" >> ${ERRORLOG};
  $DRUSH  updb --yes --strict=0 1> >(tee -a ${ERRORLOG} >&1) 2> >(tee -a ${ERRORLOG} >&2);
  result="$?";
  if [ "$result" -ne 0 ]; then
      echo -e "$(tput setab 1)$(tput setaf 7)There was and error while updating drupal core please check ${ERRORLOG} file for more information$(tput sgr 0)";
      echo -e "$(tput setab 1)$(tput setaf 7)Reverting Backup!.$(tput sgr 0)";
      revert_backup;
      exit;
  fi

  echo "$(tput setaf 2)Update is done!$(tput sgr 0)";
  echo "$(tput setaf 2)Update is done!$(tput sgr 0)" >> ${ERRORLOG};
  cd ${BASEDIR};
  reset_drush;
fi
