<?php

function get_file($url, $local_path, $newfilename)
{
    $err_msg = '';
    echo "Downloading $url";
    echo "\n";
    $out = fopen($local_path.$newfilename,"wrxb");
    if ($out == FALSE){
      print "File not opened<br>";
      exit;
    }

    $ch = curl_init();

    curl_setopt($ch, CURLOPT_FILE, $out);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    curl_setopt($ch, CURLOPT_URL, $url);

    curl_exec($ch);

    curl_close($ch);
    //fclose($handle);

}//end function

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

if (!file_exists(getcwd().'/drush')) {
    mkdir(getcwd().'/drush', 0777, true);
}

get_file("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/scripts/composer/VarbaseUpdate.php", getcwd().'/scripts/composer/', 'VarbaseUpdate.php');
get_file("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/scripts/composer/update-varbase.sh", getcwd().'/scripts/composer/', 'update-varbase.sh');
get_file("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/tags.json", '', 'tags.json');
get_file("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/drush/policy.drush.inc", getcwd().'/drush/', 'policy.drush.inc');
get_file("https://raw.githubusercontent.com/Vardot/varbase-project/8.6.x-update/drush/README.md", getcwd().'/drush/', 'README.md');

if(file_put_contents($path, $jsondata)) {
  echo "varbase-project successfully updated.\n";
  echo "Now you can run ./scripts/composer/update-varbase.sh to update varbase to latest version.\n";
  echo "Thank you.\n";
}
