#!/bin/bash

if [[ -z "$BASE_PATH" ]];then
    cd "$(dirname "$0")"
    cd ..
    export BASE_PATH=$(pwd)
    source $BASE_PATH/bin/common.sh
fi

cd $BASE_PATH

githubHugoPath=/home/ec2-user/hugo/github/t5/

echo "[INFO] Add feeds for Apple Podcast"
cleanFeed(){
        feedpath=$1
        feedpathLocal="${feedpath/category/categories}"
        absPath=${githubHugoPath}/content${feedpathLocal}
        mkdir -p "$absPath"
        cd "$absPath"

        f=feed.xml
        rm -f $f
        wget --no-check-certificate -O $f "https://t5.shwchurch.org${feedpath}feed/"

        sed -i "s#//.*.shwchurch.org#//${publicGitUsername}.github.io#g" $f
        sed -i "s#www.shwchurch.cloudns.asia#${publicGitUsername}.github.io#g" $f
        sed -i 's#/feed/"#/feed.xml"#g' $f
        sed -i 's#/category/#/categories/#g' $f
}
cd ${githubHugoPath}/content

cleanFeed "/"
cleanFeed "/category/讲道/"
cleanFeed "/category/主日敬拜程序/"


