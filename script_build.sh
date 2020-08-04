#!/bin/bash

# curl https://raw.githubusercontent.com/Rpingat/TS/master/script_build.sh>script_build.sh
# Make necessary changes before executing script

# Export some variables
user=
OUT_PATH="out/target/product/$device"
tg_username=@
ROM_ZIP=Rom*.zip
folderid=gdrive_folder_id
START=$(date +%s)

# Colors makes things beautiful
export TERM=xterm

    red=$(tput setaf 1)             #  red
    grn=$(tput setaf 2)             #  green
    blu=$(tput setaf 4)             #  blue
    cya=$(tput setaf 6)             #  cyan
    txtrst=$(tput sgr0)             #  Reset

# Send message to TG
read -r -d '' msg <<EOT
<b>Build Started</b>

<b>Device:-</b> ${device}
<b>Job Number:-</b> ${BUILD_NUMBER}
<b>Started by:-</b> ${tg_username}

Check progress <a href="${BUILD_URL}console">HERE</a>
EOT
telegram-send --format html "$msg"
# Ccache
if [ "$use_ccache" = "yes" ];
then
echo -e ${blu}"CCACHE is enabled for this build"${txtrst}
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR=/home/$user/ccache
ccache -M 75G
fi

if [ "$use_ccache" = "clean" ];
then
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR=/home/$user/ccache
ccache -C
export USE_CCACHE=1
ccache -M 75G
wait
echo -e ${grn}"CCACHE Cleared"${txtrst};
fi

# Clean build
if [ "$make_clean" = "yes" ];
then
make clean && make clobber
wait
echo -e ${cya}"OUT dir from your repo deleted"${txtrst};
fi

if [ "$make_clean" = "installclean" ];
then
make installclean
rm -rf ${OUT_PATH}/${ROM_ZIP}
wait
echo -e ${cya}"Images deleted from OUT dir"${txtrst};
fi

# Time to build
source build/envsetup.sh
lunch rom_"$device"-"$build_type"
make bacon -j32

END=$(date +%s)
TIME=$(echo $((${END}-${START})) | awk '{print int($1/60)" Minutes and "int($1%60)" Seconds"}')

if [ `ls $OUT_PATH/$ROM_ZIP 2>/dev/null | wc -l` != "0" ]; then
cd $OUT_PATH
RZIP="$(ls ${ROM_ZIP})"
fileid=$(gdrive upload --parent ${folderid} ${RZIP} | tail -1 | awk '{print $2}')
link="https://drive.google.com/file/d/$fileid/view?usp=drivesdk"
# Send message to TG
read -r -d '' suc <<EOT
<b>Build Finished</b>

<b>Time:-</b> ${TIME}
<b>Device:-</b> ${device}
<b>Build status:-</b> Success
<b>Download:-</b> <a href="${link}">$RZIP</a>
Check console output <a href="${BUILD_URL}console">HERE</a>
EOT
telegram-send --format html "$suc"
else
# Send message to TG
read -r -d '' fail <<EOT
<b>Build Finished</b>

<b>Time:-</b> ${TIME}
<b>Device:-</b> ${device}
<b>Build status:-</b> Failed

Check what caused build to fail <a href="${BUILD_URL}console">HERE</a>
EOT
telegram-send --format html "$fail"
fi
