#!/bin/bash

# curl https://raw.githubusercontent.com/Rpingat/TS/master/script_build.sh>script_build.sh
# Make necessary changes before executing script

# Export some variables
user=
lunch_command=
device_codename=
build_type=
HOME_DIR="/home/ravi"
CURRENT_DIR=$(pwd)
OUT_PATH="out/target/product/$device_codename"
tg_username=@
ROM_ZIP=Rom*.zip
upload_sftp=
tgsend_conf=example.conf
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

<b>Device:-</b> ${device_codename}
<b>Job Number:-</b> ${BUILD_NUMBER}
<b>Started by:-</b> ${tg_username}

Check progress <a href="${BUILD_URL}console">HERE</a>
EOT
telegram-send --format html "$msg"
#telegram-send --format html "$msg" --config ~/${tgsend_conf}
# Ccache
if [ "$use_ccache" = "yes" ];
then
echo -e ${blu}"CCACHE is enabled for this build"${txtrst}
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR=/home/$user/ccache
ccache -M 50G
ccache -o compression=true
fi

if [ "$use_ccache" = "clean" ];
then
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR=/home/$user/ccache
ccache -C
export USE_CCACHE=1
ccache -M 50G
ccache -o compression=true
wait
echo -e ${grn}"CCACHE Cleared"${txtrst};
fi

rm -rf ${OUT_PATH}/${ROM_ZIP} #clean rom zip in any case

# Time to build
source build/envsetup.sh
# Make clean
if [ "$make_clean" = "yes" ];
then
make clean
wait
echo -e ${cya}"OUT dir from your repo deleted"${txtrst};
fi

if [ "$make_clean" = "installclean" ];
then
make installclean
wait
echo -e ${cya}"Images deleted from OUT dir"${txtrst};
fi
lunch "$lunch_command"_"$device_codename"-"$build_type"
make bacon -j$(nproc --all)

END=$(date +%s)
TIME=$(echo $((${END}-${START})) | awk '{print int($1/60)" Minutes and "int($1%60)" Seconds"}')

export SSHPASS=""

if [ `ls $OUT_PATH/$ROM_ZIP 2>/dev/null | wc -l` != "0" ]; then
cd $OUT_PATH
RZIP="$(ls ${ROM_ZIP})"

if [ "$upload_sftp" = "yes" ];
then
   ~/sshpass -e sftp -oBatchMode=no -b - user@frs.thunderserver.in << !
     cd /${user}
     put ${RZIP}
     bye
!
link="https://dl.thunderserver.in/${user}/${RZIP}"
else
rclone copy ${RZIP} gdrive:
link=" "
fi

# Send message to TG
read -r -d '' suc <<EOT
<b>Build Finished</b>

<b>Time:-</b> ${TIME}
<b>Device:-</b> ${device_codename}
<b>Build status:-</b> Success
<b>Download:-</b> <a href="${link}">$RZIP</a>

Check console output <a href="${BUILD_URL}console">HERE</a>

cc: ${tg_username}
EOT
telegram-send --format html "$suc"
#telegram-send --format html "$suc" --config ~/${tgsend_conf}
else
#Upload error log to stagbin & katbn
cd ${CURRENT_DIR}
stagbin=$(python3 ${HOME_DIR}/stagbin.py)
katbn=$(python3 ${HOME_DIR}/katbn.py)

# Send message to TG
read -r -d '' fail <<EOT
<b>Build Finished</b>

<b>Time:-</b> ${TIME}
<b>Device:-</b> ${device_codename}
<b>Build status:-</b> Failed

Error logs:- <a href="${stagbin}">StagBin</a> | <a href="${katbn}">Katbn</a>

Check what caused build to fail <a href="${BUILD_URL}console">HERE</a>

cc: ${tg_username}
EOT
telegram-send --format html "$fail"
#telegram-send --format html "$fail" --config ~/${tgsend_conf}
exit 1
fi
