FROM server-index-exchange

RUN node ./node_modules/eslint/bin/eslint.js --ignore-path=./teads/.eslintignore ./teads

CMD ["sh", "-c", "cd teads && npm run debug"]

EXPOSE 5837
