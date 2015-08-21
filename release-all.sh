#!/bin/sh

echo "---------------------------------------------------"
echo " Releasing apiman.  Many steps to follow.  Please"
echo " play along at home..."
echo "---------------------------------------------------"
echo ""
echo ""

echo "---------------------------------------------------"
echo " Tell me what version we're releasing!"
echo "---------------------------------------------------"
echo ""

RELEASE_VERSION=$1
DEV_VERSION=$2
BRANCH=$3

if [ "x$RELEASE_VERSION" = "x" ]
then
  read -p "Release Version: " RELEASE_VERSION
fi

if [ "x$DEV_VERSION" = "x" ]
then
  read -p "New Development Version: " DEV_VERSION
fi

if [ "x$BRANCH" = "x" ]
then
  read -p "Release Branch: [master] " BRANCH
fi
if [ "x$BRANCH" = "x" ]
then
  BRANCH=master
fi

echo "######################################"
echo "Release Version: $RELEASE_VERSION"
echo "Dev Version: $DEV_VERSION"
echo "Release Branch: $BRANCH"
echo "######################################"
echo ""



echo "---------------------------------------------------"
echo " Resetting 'target' directory."
echo "---------------------------------------------------"
echo ""
rm -rf target
mkdir target

echo "---------------------------------------------------"
echo " Checking out required apiman git repos."
echo "---------------------------------------------------"
echo ""
mkdir target/git-repos
cd target/git-repos
git clone git@github.com:apiman/apiman-quickstarts.git
git clone git@github.com:apiman/apiman.git
git clone git@github.com:apiman/apiman-plugins.git
git clone git@github.com:apiman/apiman-manager-ui.git
git clone git@github.com:apiman/apiman-guides.git
git clone git@github.com:apiman/apiman-wildfly-docker.git


echo "---------------------------------------------------"
echo " Release apiman-quickstarts"
echo "---------------------------------------------------"
pushd .
cd apiman-quickstarts
git checkout $BRANCH
./release.sh $RELEASE_VERSION $DEV_VERSION

echo ""
echo ""
echo " ***** USER ACTION REQUIRED *****"
echo "Please use Nexus to release apiman-quickstarts!"
read -p "Press enter when done." USER_INPUT
popd




echo "---------------------------------------------------"
echo " Release apiman"
echo "---------------------------------------------------"
pushd .
cd apiman
git checkout $BRANCH
sed -i "s/<version.io.apiman.quickstarts>.*<\/version.io.apiman.quickstarts>/<version.io.apiman.quickstarts>$RELEASE_VERSION<\/version.io.apiman.quickstarts>/g" pom.xml
git add .
git commit -m "Updated apiman-quickstarts version to $RELEASE_VERSION"
./release.sh $RELEASE_VERSION $DEV_VERSION

echo ""
echo ""
echo " ***** USER ACTION REQUIRED *****"
echo "Please use Nexus to release apiman!"
read -p "Press enter when done." USER_INPUT
popd



echo "---------------------------------------------------"
echo " Upload apiman distro to jboss.org"
echo "---------------------------------------------------"
pushd .
cd ~/tmp/apiman-releases
echo "  Now connecting to jboss.org - please run these remote commands:"
echo ""
echo "mkdir $RELEASE_VERSION"
echo "cd $RELEASE_VERSION"
echo "put apiman-distro-wildfly8-$RELEASE_VERSION-overlay.zip"
echo "put apiman-distro-eap64-$RELEASE_VERSION-overlay.zip"
sftp overlord@filemgmt.jboss.org:downloads_htdocs/overlord/apiman
popd




echo "---------------------------------------------------"
echo " Release apiman-plugins"
echo "---------------------------------------------------"
pushd .
cd apiman-plugins
git checkout $BRANCH
sed -i "s/<version.apiman>.*<\/version.apiman>/<version.apiman>$RELEASE_VERSION<\/version.apiman>/g" pom.xml
git add .
git commit -m "Updated apiman version to $RELEASE_VERSION"
./release.sh $RELEASE_VERSION $DEV_VERSION

echo ""
echo ""
echo " ***** USER ACTION REQUIRED *****"
echo "Please use Nexus to release apiman-plugins!"
read -p "Press enter when done." USER_INPUT
popd




echo "---------------------------------------------------"
echo " Release apiman-manager-ui"
echo "---------------------------------------------------"
pushd .
cd apiman-manager-ui
BOWER_VERSION=`echo "v$RELEASE_VERSION" | sed 's/.Final//g'`
./release.sh $RELEASE_VERSION $BOWER_VERSION
popd


echo "---------------------------------------------------"
echo " Release apiman-wildfly-docker"
echo "---------------------------------------------------"
pushd .
cd apiman-wildfly-docker
git remote add upstream git@github.com:jboss-dockerfiles/apiman.git
git checkout -b apiman-$RELEASE_VERSION
cd apiman-wildfly
sed -i "s/ENV.APIMAN_VERSION.*$/ENV APIMAN_VERSION $RELEASE_VERSION/g" Dockerfile
git add . --all
git commit -m "Released apiman $RELEASE_VERSION"
git push origin apiman-$RELEASE_VERSION
echo ""
echo ""
echo " ***** USER ACTION REQUIRED *****"
echo "Please use github to submit a Pull Request!"
echo "   https://github.com/apiman/apiman-wildfly-docker"
echo ""
read -p "Press enter when done." USER_INPUT
popd


echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo ""
echo " Remaining release tasks:"
echo "   * Release a new Dockerfile"
echo "   * Release the appropriate version in JIRA"
echo "   * Update the website"
echo "   * Send a tweet!"
echo "   * Send an email to apiman-users mailing list"
echo "---------------------------------------------------"
