<?php

echo "Varbase-project updater started!\n";

$path = getcwd()."/composer.json";
if(!file_exists($path)){
  echo "Please run this command from your varbase-project root directory";
}
$string = file_get_contents(getcwd()."/composer.json");
$json=json_decode($string,true);

if(isset($json["name"]) && $json["name"] != "vardot/varbase-project"){
  echo "Please run this command from your varbase-project root directory";
}

if(!isset($json["name"])){
  echo "Please run this command from your varbase-project root directory";
}

if(!isset($json["autoload"])){
  $json["autoload"] = [
    "psr-4" => [
      "Varbase\\composer\\" => "scripts/composer"
    ]
  ];
}else if(isset($json["autoload"]["psr-4"])){
  $json["autoload"]["psr-4"]["Varbase\\composer\\"] = "scripts/composer";
}else{
  $json["autoload"]["psr-4"] = [
    "Varbase\\composer\\" => "scripts/composer"
  ];
}

if(!isset($json["scripts"])){
  $json["scripts"] = [
    "varbase-composer-generate" => [
      "Varbase\\composer\\VarbaseUpdate::generate"
    ],
    "varbase-update" => [
      "Varbase\\composer\\VarbaseUpdate::updateVarbase"
    ]
  ];
}else if(isset($json["scripts"])){
  $json["scripts"]["varbase-composer-generate"]= [
    "Varbase\\composer\\VarbaseUpdate::generate"
  ];
  $json["scripts"]["varbase-update"]= [
    "./scripts/composer/update-varbase.sh"
  ];
}
$drupalPath = "docroot";
if (file_exists(getcwd().'/web')) {
  $drupalPath = "web";
}
if(!isset($json["extra"])){
  $json["extra"] = [
    "install-path" => $drupalPath
  ];
}else{
  $json["extra"]["install-path"] = $drupalPath;
}

$jsondata = json_encode($json, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES);


if (!file_exists(getcwd().'/scripts/composer')) {
    mkdir(getcwd().'/scripts/composer', 0777, true);
}

file_put_contents(getcwd().'/scripts/composer/VarbaseUpdate.php', fopen("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/scripts/composer/VarbaseUpdate.php", 'r'));

file_put_contents("tags.json", fopen("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/tags.json", 'r'));

if(file_put_contents($path, $jsondata)) {
  echo "varbase-project successfully updated.\n";
  echo "Now you can run composer varbase-update to update varbase to latest version.\n";
  echo "Thank you.\n";
}
