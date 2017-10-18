#!/usr/bin/env bash

# set fail on error
#set -eE
# set root project directory
TOP=.

## create source dir
mkdir -pv ${TOP}/images
rm -Rvf ${TOP}/images/*

# create mountpoint
mkdir -pv ${TOP}/rpi_mnt


# set image download target
image_uri="https://s3-us-west-2.amazonaws.com/bootstrap.mycroft.ai/mark-1/mark-1_production_build-8_2017-08-11.zip"

# get image and unpack
pushd ${TOP}/images
wget -vL ${image_uri}
unzip ./*.zip
rm *.zip
mv -v *.img test.img
popd

#create loopback device
pushd ./images
loopback_device=$(losetup -f -P --show *.img)
echo ${loopback_device}
pushd

# mount the loopback device to a local folder
mount ${loopback_device}p2  ${TOP}/rpi_mnt

# cp binfmt support file into image mount
cp -v /usr/bin/qemu-arm-static ${TOP}/rpi_mnt/usr/bin

# spawn a systemd container and run these commands in it (download the test-upgrade.sh script

systemd-nspawn -q --bind /usr/bin/qemu-arm-static  -D rpi_mnt /bin/bash << EOF
wget https://gist.githubusercontent.com/MatthewScholefield/a15cfe1b5583e8f7acbf621cb4cee15a/raw/d8c775c33fd3de56aa8ab2137069157f16b49f46/test-upgrade.sh
chmod +x test-upgrade.sh
./test-upgrade.sh
EOF

# unmount the loopback device
umount -l ./rpi_mnt
#remove loopback device
losetup -d ${loopback_device}


