#!/bin/bash

set -e

if [ -z ${SOLR_VERSION}  ]; then
    SOLR_VERSION="4.10.4"
fi

cd $(dirname $0)

export TEST_ROOT=$(pwd)
export SOLR_ARCHIVE="${SOLR_VERSION}.tgz"

if [ -d "${HOME}/download-cache/" ]; then
    export SOLR_ARCHIVE="${HOME}/download-cache/${SOLR_ARCHIVE}"
fi

if [ -f ${SOLR_ARCHIVE} ]; then
    # If the tarball doesn't extract cleanly, remove it so it'll download again:
    tar -tf ${SOLR_ARCHIVE} > /dev/null || rm ${SOLR_ARCHIVE}
fi

if [ ! -f ${SOLR_ARCHIVE} ]; then
    python get-solr-download-url.py $SOLR_VERSION | xargs curl -Lo $SOLR_ARCHIVE
fi

if [ ${SOLR_VERSION} = "4.10.4" ]; then
    echo "Extracting Solr ${SOLR_VERSION} to `pwd`/solr4/"
    rm -rf solr4
    mkdir solr4
    tar -C solr4 -xf ${SOLR_ARCHIVE} --strip-components 2 solr-${SOLR_VERSION}/example
    tar -C solr4 -xf ${SOLR_ARCHIVE} --strip-components 1 solr-${SOLR_VERSION}/dist solr-${SOLR_VERSION}/contrib

    echo "Changing into solr4"

    cd solr4

    echo "Configuring Solr"

    cp ${TEST_ROOT}/solrconfig.xml solr/collection1/conf/solrconfig.xml
    cp ${TEST_ROOT}/schema.xml solr/collection1/conf/schema.xml

    # Fix paths for the content extraction handler:
    perl -p -i -e 's|<lib dir="../../../contrib/|<lib dir="../../contrib/|'g solr/*/conf/solrconfig.xml
    perl -p -i -e 's|<lib dir="../../../dist/|<lib dir="../../dist/|'g solr/*/conf/solrconfig.xml

    # Add MoreLikeThis handler
    perl -p -i -e 's|<!-- A Robust Example|<!-- More like this request handler -->\n  <requestHandler name="/mlt" class="solr.MoreLikeThisHandler" />\n\n\n  <!-- A Robust Example|'g solr/*/conf/solrconfig.xml

    echo 'Starting server'
    # We use exec to allow process monitors to correctly kill the
    # actual Java process rather than this launcher script:
    export CMD="java -Djetty.port=9001 -Djava.awt.headless=true -Dapple.awt.UIElement=true -jar start.jar"

    if [ -z "${BACKGROUND_SOLR}" ]; then
        exec $CMD
    else
        exec $CMD >/dev/null &
    fi
fi

if [ ${SOLR_VERSION} = "5.2.1" ]; then
    if [ -z ${SOLR_CORENAME}  ]; then
        SOLR_CORENAME="haystacktestcore"
    fi

    echo "Extracting Solr ${SOLR_VERSION} to `pwd`/solr-${SOLR_VERSION}/"
    tar -xf ${SOLR_ARCHIVE}
    echo "Changing into solr5"
    cd solr-${SOLR_VERSION}

    # We use exec to allow process monitors to correctly kill the
    # actual Java process rather than this launcher script:
    export CMD="bin/solr start -p 9001"
    echo 'Starting server on port 9001'
    exec $CMD
    echo "Configuring Solr 5 Core named ${SOLR_CORENAME}"
    sudo -u solr bin/solr create -c $SOLR_CORENAME
fi
