#!/bin/sh
set -xe

if [ -z $FROM_TEST ]
  then
    # Install local teads-central (documented @ https://confluence.teads.net/display/INFRA/teads-central+documentation)
    curl -sL http://dl.teads.net/teads-central/get.sh | sh -
    # Common variables
    REG_URL=$(./teads-central docker dev-registry-url)
    sed -i -e "s/REGISTRY_URL_INJECTED_BY_TEST_SH/$REG_URL/" *.Dockerfile
    IMAGE=$(./teads-central vars image)
    HASH=$(./teads-central vars hash)
    TAG=$(./teads-central vars tag)
    sed -i -e "s/REGISTRY_URL_INJECTED_BY_TEST_SH/$REG_URL/" *.Dockerfile
    docker build -f wiremock.Dockerfile -t wiremock-$IMAGE:$HASH .
    docker build -f server.Dockerfile -t server-$IMAGE .
    WIREMOCK_NAME="localhost"
else
    WIREMOCK_NAME="$IMAGE-wiremock"
fi

SERVER_DEBUGGER_NAME="$IMAGE-server-debugger"

WIREMOCK_PORT_HTTP=8080
WIREMOCK_PORT_HTTPS=8443
NEW_WIREMOCK_MAPPING_URL="http://$WIREMOCK_NAME:$WIREMOCK_PORT_HTTP/__admin/mappings/new"

docker run -d \
      --name $TAG-$WIREMOCK_NAME \
      -p 8080:8080 \
      -p 8443:8443 \
      wiremock-$IMAGE:$HASH

./teads-central docker wait-for -c $TAG-$WIREMOCK_NAME:8443 -p tcp -t 10s

docker run -d \
      --name $TAG-$SERVER_DEBUGGER_NAME \
      --link $TAG-$WIREMOCK_NAME:$WIREMOCK_NAME \
      -p 5837:5837 \
      -p 5838:5838 \
      server-$IMAGE \
      sh -c "cd teads;
        sed -i -e \"s/\\\$WIREMOCK_HOST/$WIREMOCK_NAME/g; s/\\\$WIREMOCK_PORT/$WIREMOCK_PORT_HTTPS/g\" ./client-test/ssp-mock-routes/bid-request.json ./client-test/ssp-mock-routes/ad.json;
        curl -X POST -H 'Content-Type: application/json' --data-binary '@./client-test/ssp-mock-routes/bid-request.json' '$NEW_WIREMOCK_MAPPING_URL';
        curl -X POST -H 'Content-Type: application/json' --data-binary '@./client-test/ssp-mock-routes/ad.json' '$NEW_WIREMOCK_MAPPING_URL';
        curl -X POST -H 'Content-Type: application/json' --data-binary '@./client-test/ssp-mock-routes/tracking.json' '$NEW_WIREMOCK_MAPPING_URL';
        sed -i -e \"s/plain'/plain',withCredentials: false/g; s/a\.teads\.tv/$WIREMOCK_NAME:$WIREMOCK_PORT_HTTPS/g\" ./teads-htb.js;
        npm run debug"

./teads-central docker wait-for -c $TAG-$SERVER_DEBUGGER_NAME:5837 -p tcp -t 10s
./teads-central docker wait-for -c $TAG-$SERVER_DEBUGGER_NAME:5838 -p tcp -t 10s

if [ -z $FROM_TEST ]
  then
    set +x
    echo "\n==========================================================================================="
    echo "INDEX-EXCHANGE debugger for Teads"
    echo "===========================================================================================\n"
    echo "Before you begin, please make sure to follow the following instructions:\n"
    echo "Please accept certificate for following https://$WIREMOCK_NAME:$WIREMOCK_PORT_HTTPS\n"
    echo "To start debugging, go to either :\n"
    echo "\tHTTP: http://localhost:5837/public/debugger/adapter-debugger.html (non-safe-frame testing)"
    echo "\tHTTPS: https://localhost:5838/public/debugger/adapter-debugger.html (safe-frame testing)\n"
    echo "===========================================================================================\n"
fi
