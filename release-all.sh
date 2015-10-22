#!/bin/sh

set -e


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
GPG_PASSPHRASE=$4

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

if [ "x$GPG_PASSPHRASE" = "x" ]
then
  read -p "GPG Passphrase: " GPG_PASSPHRASE
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
git clone git@github.com:apiman/apiman-plugin-registry.git
git clone git@github.com:apiman/apiman-service-catalog.git
git clone git@github.com:apiman/apiman.git
git clone git@github.com:apiman/apiman-plugins.git
git clone git@github.com:apiman/apiman-wildfly-docker.git
git clone git@github.com:apiman/apiman-deployer.git



echo "---------------------------------------------------"
echo " Update version #s and validate all builds
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apiman
pushd .
cd apiman
git checkout $BRANCH
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
mvn clean install
popd
push d.
cd apiman-plugins
git checkout $BRANCH
sed -i "s/<version.apiman>.*<\/version.apiman>/<version.apiman>$RELEASE_VERSION<\/version.apiman>/g" pom.xml
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
mvn clean install
popd



echo "---------------------------------------------------"
echo " Release apiman-plugin-registry"
echo "---------------------------------------------------"
pushd .
cd apiman-plugin-registry
git checkout $BRANCH
sed -i -r "s/\"version\".?:.?\".*\"/\"version\" : \"$RELEASE_VERSION\"/g" registry.json

git add .
git commit -m "Prepare for release $RELEASE_VERSION"
git push origin $BRANCH
git tag -a -m "Tagging release $RELEASE_VERSION" $RELEASE_VERSION
git push origin $RELEASE_VERSION

sed -i -r "s/\"version\".?:.?\".*\"/\"version\" : \"$DEV_VERSION\"/g" registry.json
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH

popd



echo "---------------------------------------------------"
echo " Release apiman-service-catalog"
echo "---------------------------------------------------"
pushd .
cd apiman-service-catalog
git checkout $BRANCH
git tag -a -m "Tagging release $RELEASE_VERSION" $RELEASE_VERSION
git push origin $RELEASE_VERSION
popd



echo "---------------------------------------------------"
echo " Release apiman"
echo "---------------------------------------------------"
pushd .
cd apiman

sed -i "s/apiman-manager.plugins.registries=.*$/apiman-manager.plugins.registries=http:\/\/cdn.rawgit.com\/apiman\/apiman-plugin-registry\/$RELEASE_VERSION\/registry.json/g" distro/wildfly8/src/main/resources/overlay/standalone/configuration/apiman.properties
sed -i "s/apiman-manager.service-catalog.catalog-url=.*$/apiman-manager.service-catalog.catalog-url=http:\/\/cdn.rawgit.com\/apiman\/apiman-service-catalog\/$RELEASE_VERSION\/catalog.json/g" distro/wildfly8/src/main/resources/overlay/standalone/configuration/apiman.properties

git add . --all
git commit -m "Prepared apiman for release: $RELEASE_VERSION"
git push origin $BRANCH
git tag -a -m "Tagging release $RELEASE_VERSION" apiman-$RELEASE_VERSION
git push origin apiman-$RELEASE_VERSION

mvn clean deploy -Dgpg.passphrase=$GPG_PASSPHRASE

rm -rf ~/.apiman
mkdir ~/.apiman
mkdir ~/.apiman/releases
cp distro/wildfly8/target/*.zip ~/.apiman/releases
cp distro/eap64/target/*.zip ~/.apiman/releases

mvn versions:set -DnewVersion=$DEV_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH

sed -i "s/apiman-manager.plugins.registries=.*$/apiman-manager.plugins.registries=http:\/\/rawgit.com\/apiman\/apiman-plugin-registry\/$BRANCH\/registry.json/g" distro/wildfly8/src/main/resources/overlay/standalone/configuration/apiman.properties
sed -i "s/apiman-manager.service-catalog.catalog-url=.*$/apiman-manager.service-catalog.catalog-url=http:\/\/rawgit.com\/apiman\/apiman-service-catalog\/$BRANCH\/catalog.json/g" distro/wildfly8/src/main/resources/overlay/standalone/configuration/apiman.properties
git add .
git commit -m "Set plugin-registry and service-catalog URLs to dev versions."
git push origin $BRANCH
popd



echo "---------------------------------------------------"
echo " Upload apiman distro to jboss.org"
echo "---------------------------------------------------"
pushd .
cd ~/.apiman/releases
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

git add . --all
git commit -m "Prepared apiman for release: $RELEASE_VERSION"
git push origin $BRANCH
git tag -a -m "Tagging release $RELEASE_VERSION" apiman-plugins-$RELEASE_VERSION
git push origin apiman-plugins-$RELEASE_VERSION

mvn clean deploy -Dgpg.passphrase=$GPG_PASSPHRASE

mvn versions:set -DnewVersion=$DEV_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH
popd



echo "---------------------------------------------------"
echo " Release apiman-deployer script"
echo "---------------------------------------------------"
pushd .
cd apiman-deployer
git checkout $BRANCH

sed -i "s/APIMAN_VERSION=.*$/APIMAN_VERSION=$RELEASE_VERSION/g" deployer.sh

git add .
git commit -m "Prepare for release $RELEASE_VERSION"
git push origin $BRANCH
git tag -a -m "Tagging release $RELEASE_VERSION" $RELEASE_VERSION
git push origin $RELEASE_VERSION

sed -i "s/APIMAN_VERSION=.*$/APIMAN_VERSION=$DEV_VERSION/g" deployer.sh
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH

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
