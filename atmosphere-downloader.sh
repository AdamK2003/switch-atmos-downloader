#!/usr/bin/env bash
echo "AdamSkI2003\'s Atmosphére downloader"

# NOTE: This script will run interactively if invoked without arguments. It switches to non-interactive mode if a path is passed as an argument.

mesosphere="1" # change to 0 to use zip without mesosphere in non-interactive mode
mismatchcrash="0" # change to 1 to make the script exit with code 2 if it detects a sigpatches mismatch

# check if required packages exist
if [[ "`command -v jq`" = "" ]]; then
  echo "jq not found, the script will not work"
  exit 1
fi
if [[ "`command -v curl`" = "" ]]; then
  echo "curl not found, the script will not work"
  exit 1
fi
if [[ "`command -v wget`" = "" ]]; then
  echo "wget not found, the script will not work"
  exit 1
fi
if [[ "`command -v unzip`" = "" ]]; then
  echo "unzip not found, the script will not work"
  exit 1
fi

# check for path argument, ask for path if empty
if [[ "$@" != "" ]]; then # check if path was given as arg
  patharg='1' # value is 1 if path was given as arg, else 0
  pathinput="$@"
  path="`readlink -m $pathinput`"
  if [[ "$?" != 0 ]]; then
    echo "The path couldn't be parsed correctly"
    exit 1
  fi
else # ask user for path
  x="0"
  patharg='0'
  while  [[ $x = "0" ]]; do # loop back to input prompt until path is parsed correctly
    echo "Destination path:"
    read -p "path > " pathinput
    path="`readlink -m $pathinput`"
    if [[ "$?" != 0 ]]; then # check exit code of readlink command, prompt user to try again if non-zero
      echo "The path couldn't be parsed correctly, try again"
    else
      x="1"
      echo "Absolute path is $path"
    fi
  done
fi
x="0"
mkdir -p "$path"
cd "$path"



# define API links now to avoid clutter later on (nevermind)
atmosurl="https://api.github.com/repos/Atmosphere-NX/Atmosphere/releases/latest"
hekateurl="https://api.github.com/repos/CTCaer/hekate/releases/latest"
patchesurl="https://api.github.com/repos/ITotalJustice/patches/releases/latest"

# API parsing time

mkdir -p $path/temp/api

# download API data to temp files
echo "Downloading API data..."
wget "$atmosurl" -q -O $path/temp/api/atmos.json
wget "$hekateurl" -q -O $path/temp/api/hekate.json
wget "$patchesurl" -q -O $path/temp/api/patches.json
echo "API data downloaded!"

asset2name=$( jq .assets[2].name -r $path/temp/api/atmos.json ) # FIXME I forgot the goddamn -r flag earlier
asset1name=$( jq .assets[1].name -r $path/temp/api/atmos.json )

# check if asset 2 is still fusee-primary
if [ "$asset2name" != "fusee-primary.bin" ]; then
  if [ "$asset1name" != "fusee-primary.bin" ]; then
    echo "Either the script broke or I didn't predict something"
    exit 3
  fi
  assetremoved="1"
fi

# ask user for atmos version (mesosphere/no mesosphere)
# TODO remove this if "no mesosphere" zip gets removed
if [[ $assetremoved = 0 ]]; then
  if [[ $patharg = "0" ]]; then
    echo "Mesosphere zip? (default is yes)"
    read -p "yes/no > " mesoinput
    if [[ "$mesoinput" = "no" ]]; then
      meso="0"
      echo "Using zip without mesosphere"
    else
      meso="1"
      echo "Using mesosphere zip"
    fi
  else
    if [[ "$mesosphere" = "0" ]]; then
      meso="0"
      echo "Using zip without mesosphere"
    else
      meso="1"
      echo "Using mesosphere zip"
    fi
  fi
else
  meso="1"
fi

# get versions
atmosver=$( jq -r .tag_name $path/temp/api/atmos.json )
hekatever=$( jq -r .tag_name $path/temp/api/hekate.json )
patchesver=$( jq -r .tag_name $path/temp/api/patches.json )

if [[ "$patchesver" == *"$atmosver"* ]]; then # warn if patches may not be compatible
  patcheswarn="0"
else
  if [[ "$mismatchcrash" = "1" ]]; then # exit if patch mismatch was detected and the mismatchcrash var is set to 1
    echo "Sigpatches mismatch detected!"
    exit 2
  fi
  patcheswarn="1"
fi

# show summary

echo ""
if [[ $meso="1" ]]; then
  echo "Atmosphere (with mesosphere) version $atmosver"
else
  echo "Atmosphere (without mesosphere) version $atmosver"
fi
echo "Hekate version $hekatever"
echo "Sigpatches version $patchesver"
echo "Tinfoil (latest)"
echo ""
if [[ $patcheswarn = 1 ]]; then # sigpatches warning
  echo "!!! Sigpatches probably weren't updated yet! !!!"
  echo "!!! Atmosphere version: $atmosver            !!!"
  echo "!!! Sigpatches version: $patchesver          !!!"
  echo ""
fi
if [[ $patharg = "0" ]]; then
  echo "Do you want to continue?"
  read -p "yes/no > " continueinput
  if [[ "$continueinput" = "no" ]]; then
    echo "Cancelled by user"
    exit 1
  fi
fi

# find file URLs

if [[ $meso = "1" ]]; then
  atmosdl=$( jq .assets[0].browser_download_url -r $path/temp/api/atmos.json )
else
  atmosdl=$( jq .assets[1].browser_download_url -r $path/temp/api/atmos.json )
fi
if [[ $assetremoved = "1" ]]; then
  fuseedl=$( jq .assets[1].browser_download_url -r $path/temp/api/atmos.json )
else
  fuseedl=$( jq .assets[2].browser_download_url -r $path/temp/api/atmos.json )
fi
hekatedl=$( jq .assets[0].browser_download_url -r $path/temp/api/hekate.json )
patchesdl=$( jq .assets[0].browser_download_url -r $path/temp/api/patches.json )
tinfoildl="https://tinfoil.media/repo/tinfoil.latest.zip"

# download the assets using wget

mkdir -p "$path/temp/assets"
wget "$atmosdl" -O "$path/temp/assets/atmos.zip"
wget "$fuseedl" -O "$path/temp/assets/fusee-primary.bin"
wget "$hekatedl" -O "$path/temp/assets/hekate.zip"
wget "$patchesdl" -O "$path/temp/assets/patches.zip"
wget "$tinfoildl" -O "$path/temp/assets/tinfoil.zip"

# unpack the zips into the proper folders
mkdir -p "$path/sd"
unzip "$path/temp/assets/atmos.zip" -d "$path/sd"
unzip "$path/temp/assets/hekate.zip" -d "$path/sd"
unzip "$path/temp/assets/patches.zip" -d "$path/sd"
unzip "$path/temp/assets/tinfoil.zip" -d "$path/sd"
cp "$path/temp/assets/fusee-primary.bin" "$path/sd/bootloader/payloads/fusee-primary.bin"
cp "$path/sd/hekate_ctcaer"* "$path/sd/atmosphere/reboot_payload.bin"

# create the hekate_ipl.ini

echo "{------ Atmosphere ------}" > "$path/sd/bootloader/hekate_ipl.ini"
echo "[Atmosphere CFW emuMMC]" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "payload=bootloader/payloads/fusee-primary.bin" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "icon=bootlogo.bmp" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "{}" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "[Atmosphere FSS0 sysMMC]" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "fss0=atmosphere/fusee-secondary.bin" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "kip1=atmosphere/kips/*" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "emummc_force_disable=1" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "icon=bootloader/res/sys_cfw_boot.bmp" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "{}" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "{-------- Stock ---------}" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "[Stock sysMMC]" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "fss0=atmosphere/fusee-secondary.bin" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "stock=1" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "emummc_force_disable=1" >> "$path/sd/bootloader/hekate_ipl.ini"
echo "icon=bootloader/res/stock_boot.bmp" >> "$path/sd/bootloader/hekate_ipl.ini"

# create zip file if zip is installed

if [[ "`command -v zip`" != "" ]]; then
  zip -r $path/sd.zip $path/sd
else
  echo "zip is not installed, unable to automatically create archive"
fi

# cleanup

rm -rf $path/temp

echo "All done!"
