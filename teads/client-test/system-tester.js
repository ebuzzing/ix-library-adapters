const puppeteer = require('puppeteer');

(async () => {
    const argv = require('minimist')(process.argv.slice(2), {
        string: [ 'host', 'port' ],
        boolean: [ 'headless' ],
        alias: { p: 'port', h: 'host' },
        default: { port: 5837, headless: true }
    });

    const serverURL = `http://${argv.host}:${argv.port}/public/tester/system-tester.html`;
    const failuresSelector = ':scope .results .failures .spec-detail.failed';
    const successSelector = ':scope .alert .bar.passed';

    const browser = await puppeteer.launch({
        headless: argv.headless,
        args: ['--no-sandbox', '--disable-dev-shm-usage'],
        executablePath: '/usr/bin/chromium-browser'
    });

    const page = await browser.newPage();

    console.log("Running teads-index system-tester checks...");
    await page.goto(serverURL).catch(e => console.log(e));

    await page
        .waitForSelector('.duration', {timeout: 60000})
        .catch(e => console.log(e));

    const duration = await page.$eval('.duration', e => e.innerHTML).catch(e => console.log(e));
    console.log(duration);

    const failedTests = await page.$$eval(
        failuresSelector,
        failures => failures.map(failure => {
            return {
                name: failure.querySelector(':scope .description a').innerText,
                stacktrace: failure.querySelector(':scope .messages .stack-trace').innerText
            };
        })
    );

    const failedTestsCount = failedTests.length;
    if (failedTestsCount > 0) {
        console.log(`Error: ${failedTestsCount} ${failedTestsCount > 1 ? "tests" : "test"} failed:`);
        failedTests.forEach(failure => {
            console.log(failure.name);
            console.log(failure.stacktrace);
            }
        );
        await screenshot(page, isTestPassed = false);
        process.exit(1);
    }
    else {
        const isSuccess = await page.$eval(
            successSelector,
            e => e
        ).catch(e => console.log(e));

        if (isSuccess) {
            console.log("All tests passed !");
            await screenshot(page, isTestPassed = true);
            process.exit();
        }
        else {
            console.log(
                'Something went wrong when checking test results.\n' +
                'Please make sure the elements on the page are still accessible.'
            );
            await screenshot(page, isTestPassed = false);
            process.exit(1);
        }

        process.exit();
    }
})();

async function screenshot(page, isTestPassed) {
    const prefix = isTestPassed ? 'success-' : 'error-';
    await page.screenshot({
        path: './screenshots/' + prefix + "system-tests-" + new Date().getTime() + '.png',
        fullPage: true
    });
}
