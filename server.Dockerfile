FROM REGISTRY_URL_INJECTED_BY_TEST_SH/node:8.11

COPY . ./app

WORKDIR ./app

RUN apk update && \
    apk upgrade && \
    apk add --no-cache git openssh && \
    npm install && \
    node ./node_modules/eslint/bin/eslint.js --ignore-path=./teads/.eslintignore ./teads

CMD ["sh", "-c", "cd teads && npm run debug"]

EXPOSE 5837

