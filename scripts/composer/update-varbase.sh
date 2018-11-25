#!/bin/bash
BASEDIR=$(PWD);
DRUPALPATH='docroot';
if [ -d "${PWD}/web" ]; then
  DRUPALPATH='web';
fi
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
  echo -e "$(tput setaf 2)Updating drupal core to latest.$(tput sgr 0)";
  mkdir -p "${PWD}/update_backups";
  cd "${PWD}/${DRUPALPATH}";
  drush dl page_manager --pm-force --yes;
  drush up drupal --pm-force --yes;
  cd "${BASEDIR}";
  echo -e "$(tput setaf 2)Updating drupal core is done.$(tput sgr 0)";
  echo -e "$(tput setaf 2)Cleanup & Update composer.json to prepare for varbase update.$(tput sgr 0)";
  composer run-script varbase-composer-generate > ${PWD}/composer.new.json;
  mkdir -p "${PWD}/update_backups/contrib";
  cp -r ${PWD}/${DRUPALPATH}/modules/contrib/media_entity_document ${PWD}/update_backups/contrib/media_entity_document;
  cp -r ${PWD}/${DRUPALPATH}/modules/contrib/media_entity_image ${PWD}/update_backups/contrib/media_entity_image;
  cp -r ${PWD}/${DRUPALPATH}/modules/contrib/login_destination ${PWD}/update_backups/contrib/login_destination;
  cp -r ${PWD}/${DRUPALPATH}/modules/contrib/node_edit_protection ${PWD}/update_backups/contrib/node_edit_protection;
  cp ${PWD}/composer.json ${PWD}/update_backups/composer.json.b;
  mv ${PWD}/composer.new.json ${PWD}/composer.json;
  echo -e "$(tput setaf 2)Update varbase to latest.$(tput sgr 0)";
  composer update;
  composer update;
  composer drupal-scaffold;
  cp -r ${PWD}/update_backups/contrib/media_entity_document ${PWD}/${DRUPALPATH}/modules/contrib/media_entity_document;
  cp -r ${PWD}/update_backups/contrib/media_entity_image ${PWD}/${DRUPALPATH}/modules/contrib/media_entity_image;
  cp -r ${PWD}/update_backups/contrib/login_destination ${PWD}/${DRUPALPATH}/modules/contrib/login_destination;
  cp -r ${PWD}/update_backups/contrib/node_edit_protection ${PWD}/${DRUPALPATH}/modules/contrib/node_edit_protection;
  cd "${PWD}/${DRUPALPATH}";
  drush cr;
  echo -e "$(tput setaf 2)Enable some required modules for latest varbase.$(tput sgr 0)";
  drush en entity_browser_generic_embed --yes;
  echo -e "$(tput setaf 2)Updating the database for latest changes.$(tput sgr 0)";
  drush updb --yes;
  echo "$(tput setaf 2)Update is done!$(tput sgr 0)";
fi
