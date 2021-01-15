#!/bin/sh -l

cd /home/build/openwrt || exit 1

cp -f feeds.conf.default feeds.conf
sed -i 's#git.openwrt.org/openwrt/openwrt#github.com/openwrt/openwrt#' feeds.conf
sed -i 's#git.openwrt.org/feed/packages#github.com/openwrt/packages#' feeds.conf
sed -i 's#git.openwrt.org/project/luci#github.com/openwrt/luci#' feeds.conf
sed -i 's#git.openwrt.org/feed/telephony#github.com/openwrt/telephony#' feeds.conf

test -d "package/openwrt-upx" && \
rm -rf "package/openwrt-upx"

git clone -b master --depth 1 https://github.com/kuoruan/openwrt-upx.git package/openwrt-upx

mkdir -p package/openwrt-xray
curl https://raw.githubusercontent.com/xiaorouji/openwrt-passwall/main/xray/Makefile -o package/openwrt-xray/Makefile

if [ "$3" = "y" ] 
then
  sed -i '/PKG_BUILD_DEPENDS/c PKG_BUILD_DEPENDS=golang\/host upx\/host' package/openwrt-xray/Makefile
else
  sed -i '/PKG_BUILD_DEPENDS/c PKG_BUILD_DEPENDS=golang\/host' package/openwrt-xray/Makefile
fi

./scripts/feeds update -a

test -d "feeds/packages/lang/golang" && \
rm -rf "feeds/packages/lang/golang"

curl https://codeload.github.com/openwrt/packages/tar.gz/master | \
tar -xz -C "feeds/packages/lang" --strip=2 packages-master/lang/golang

make defconfig

sed -i "/CONFIG_XRAY_COMPRESS_GOPROXY/c CONFIG_XRAY_COMPRESS_GOPROXY=$1" .config
sed -i "/CONFIG_XRAY_EXCLUDE_ASSETS/c CONFIG_XRAY_EXCLUDE_ASSETS=$2" .config
sed -i "/CONFIG_XRAY_COMPRESS_UPX/c CONFIG_XRAY_COMPRESS_UPX=$3" .config
sed -i "/CONFIG_XRAY_COMPATIBILITY_MODE/c CONFIG_XRAY_COMPATIBILITY_MODE=$4" .config

./scripts/feeds install zlib
./scripts/feeds install ca-certificates
./scripts/feeds install golang

make package/openwrt-xray/compile V=s

find "bin/packages/" -type f -name "xray*.ipk" -exec sudo cp -f {} "$WORKSPACE" \;
find "$WORKSPACE" -type f -name "*.ipk" -exec ls -lh {} \;

date=$(date)
echo "::set-output name=date::$date"
