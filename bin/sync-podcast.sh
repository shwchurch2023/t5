#!/bin/bash

export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh

githubHugoPath=$BASE_PATH

echo "[INFO] Add feeds for Apple Podcast"
cleanFeed(){
        feedpath=$1
        feedpathLocal=$2
        if [[ -z "${feedpathLocal}" ]];then
                feedpathLocal="${feedpath/category/categories}"
        fi
        
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
cleanFeed "/category/sermon/" "/categories/讲道/"
cleanFeed "/category/主日敬拜程序/"


