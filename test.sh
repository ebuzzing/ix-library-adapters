#!/bin/sh
set -xe

# Install local teads-central (documented @ https://confluence.teads.net/display/INFRA/teads-central+documentation)
curl -sL http://dl.teads.net/teads-central/get.sh | sh -

# Common variables
REG_URL=$(./teads-central docker dev-registry-url)
IMAGE=$(./teads-central vars image)
HASH=$(./teads-central vars hash)
TAG=$(./teads-central vars tag)

sed -i -e "s/REGISTRY_URL_INJECTED_BY_TEST_SH/$REG_URL/" *.Dockerfile

cleanup () { trap '' INT; ./teads-central docker clean-tagged; }
trap cleanup EXIT TERM
trap true INT

docker build -f server.Dockerfile -t server-$IMAGE .
docker build -f server_system_tester.Dockerfile -t server-system-tester-$IMAGE:$HASH .
docker build -f puppeteer.Dockerfile -t client-$IMAGE:$HASH .
docker build -f wiremock.Dockerfile -t wiremock-$IMAGE:$HASH .

SERVER_SYSTEM_TESTER_NAME="$IMAGE-server-system-tester"

./teads-central docker run-tagged server-system-tester-$IMAGE --local --name $SERVER_SYSTEM_TESTER_NAME
./teads-central docker wait-for --tagged -c $SERVER_SYSTEM_TESTER_NAME:5837 -p tcp -t 10s

docker run --rm -i \
  --name $TAG-$IMAGE-client-system-tester \
  --link $TAG-$SERVER_SYSTEM_TESTER_NAME:$SERVER_SYSTEM_TESTER_NAME \
  -w /app \
  -v `pwd`/teads/client-test:/app:rw \
  client-$IMAGE:$HASH \
  sh -c "node system-tester.js --host $SERVER_SYSTEM_TESTER_NAME";

export FROM_TEST=true

. ./start_debugger.sh

docker run --rm -i \
  --name $TAG-$IMAGE-client-debugger \
  --link $TAG-$SERVER_DEBUGGER_NAME:$SERVER_DEBUGGER_NAME \
  --link $TAG-$WIREMOCK_NAME:$WIREMOCK_NAME \
  -w /app \
  -v `pwd`/teads/client-test:/app:rw \
  client-$IMAGE:$HASH \
  sh -c "node adapter-debugger.js --host $SERVER_DEBUGGER_NAME; node adapter-debugger.js --host $SERVER_DEBUGGER_NAME --port 5838 --safeframe";
