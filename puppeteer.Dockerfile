FROM REGISTRY_URL_INJECTED_BY_TEST_SH/node:12.13.1-alpine3.9

# https://github.com/puppeteer/puppeteer/blob/master/docs/troubleshooting.md#running-on-alpine
# Installs latest Chromium (72) package (alpine3.9)
RUN apk add --no-cache chromium

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true

# Puppeteer v1.11.0 works with Chromium 72.
RUN yarn add puppeteer@1.11.0

