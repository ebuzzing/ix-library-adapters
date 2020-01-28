FROM REGISTRY_URL_INJECTED_BY_TEST_SH/node:8.11

COPY . ./app

WORKDIR ./app

RUN apk update && \
    apk upgrade && \
    apk add --no-cache git openssh curl && \
    npm install
