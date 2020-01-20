#!/bin/sh
set -xe

# Install local teads-central (documented @ https://confluence.teads.net/display/INFRA/teads-central+documentation)
curl -sL http://dl.teads.net/teads-central/get.sh | sh -

# Common variables
REG_URL=$(./teads-central docker dev-registry-url)

cleanup () { trap '' INT; ./teads-central docker clean-tagged; }
trap cleanup EXIT TERM
trap true INT

# common changes above this line should be done upstream #
##########################################################

sed -i -e "s/REGISTRY_URL_INJECTED_BY_TEST_SH/$REG_URL/" *.Dockerfile

IMAGE=$(./teads-central vars image)
HASH=$(./teads-central vars hash)
TAG=$(./teads-central vars tag)

SERVER_NAME="$IMAGE-server"
docker build -f server.Dockerfile -t server-$IMAGE:$HASH .
./teads-central docker run-tagged server-$IMAGE --local --name $SERVER_NAME
./teads-central docker wait-for --tagged -c $SERVER_NAME:5837 -p tcp -t 10s

CLIENT_NAME="$TAG-$IMAGE-client"

docker build -f puppeteer.Dockerfile -t client-$IMAGE:$HASH .

docker run --rm -i \
  --name $CLIENT_NAME\
  --link $TAG-$SERVER_NAME:$SERVER_NAME \
  -w /app \
  -v `pwd`/teads/client-test:/app:rw \
  client-$IMAGE:$HASH \
  sh -c "node puppeteer-test.js";
