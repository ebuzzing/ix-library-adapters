const puppeteer = require('puppeteer');

(async () => {
    const argv = require('minimist')(process.argv.slice(2), {
        string: [ 'host', 'port' ],
        boolean: [ 'headless', 'safeframe' ],
        alias: { p: 'port', h: 'host' },
        default: { port: 5837, headless: true, safeFrame: false }
    });

    const isSafeFrameTest = argv.safeframe;
    const protocol = isSafeFrameTest ? "https" : "http";
    const serverURL = `${protocol}://${argv.host}:${argv.port}/public/debugger/adapter-debugger.html`;
    const adSlotIframeId =
        isSafeFrameTest ? '#google_ads_iframe_\\/77475840\\/pktf\\/sf-price_0': '#google_ads_iframe_\\/77475840\\/pktf\\/ff-price_0';
    const adapterConfigSlotName =
        isSafeFrameTest ? "textarea-desktop-slot-config-1" : "textarea-desktop-slot-config-3";
    const expectedAdSlotSize = { w: 300, h: 250 };
    const publisherConfig = JSON.stringify(
        {
            placementId: 1,
            pageId: 1,
            sizes: [[expectedAdSlotSize.w,expectedAdSlotSize.h]]
        });

    const browser = await puppeteer.launch({
        headless: argv.headless,
        args: ['--no-sandbox', '--disable-dev-shm-usage'],
        executablePath: '/usr/bin/chromium-browser',
        ignoreHTTPSErrors: true
    });

    const page = await browser.newPage();


    var isImpressionEventTriggered = false;
    var isStartEventTriggered = false;
    var isHbSlotAvailableEventTriggered = false;

    const impressionUrlPath = '/track?action=impression';
    const startUrlPath = '/track?action=start';
    const hbSlotAvailableUrlPath = '/track?action=hbSlotAvailable';

    const devices = require('puppeteer/DeviceDescriptors');
    const iPhonex = devices['iPhone X'];
    await page.emulate(iPhonex);

    await page.setRequestInterception(true);
    page.on('request', interceptedRequest => {
        const requestUrl = interceptedRequest.url();

        // do not process tracking events triggered by format
        if (requestUrl.startsWith("https://t.teads.tv")) {
            interceptedRequest.abort("blockedbyclient");
            return;
        }

        if (requestUrl.includes(impressionUrlPath)) {
            console.log(`tracking event 'impression' has been triggered ! (url: ${requestUrl})`)
            isImpressionEventTriggered = true;
        }
        else if (requestUrl.includes(startUrlPath)) {
            console.log(`tracking event 'start' has been triggered ! (url: ${requestUrl})`)
            isStartEventTriggered = true;
        }
        else if (requestUrl.includes(hbSlotAvailableUrlPath)) {
            console.log(`tracking event 'hbSlotAvailable' has been triggered ! (url: ${requestUrl})`)
            isHbSlotAvailableEventTriggered = true;
        }
        interceptedRequest.continue({
            url: requestUrl.replace('localhost', argv.host),
        });
    });

    console.log(`Running teads-index debugger checks (safeFrame context: ${isSafeFrameTest}) ...`);
    await page.goto(serverURL).catch(e => console.log(e));

    await page
        .click(`input[type=radio][name=radio-protocol][value=${protocol}]`)
        .catch(e => console.log(e));

    await page
        .click("#adapter-tab")
        .catch(e => console.log(e));

    await page
        .type('textarea[name=textarea-adapter-config]', publisherConfig)
        .catch(e => console.log(e));


    await page
        .type(`textarea[name=${adapterConfigSlotName}]`, publisherConfig)
        .catch(e => console.log(e));

    await page
        .waitForSelector('#button-load-test', {timeout: 40000})
        .catch(e => console.log(e));

    await page
        .click("#button-load-test")
        .catch(e => console.log(e));

    await page.waitFor(3000); // wait for iframe to be fully loaded

    const iframeElement = await page.$('#ad-displayer');
    const iframe = await iframeElement.contentFrame();
    await iframe.waitForSelector("#button-display");
    await iframe.click("#button-display").catch(e => console.log(e));

    await iframe.waitFor(5000); // wait for iframe to be fully loaded

    const adSlotSize = await iframe.$eval(adSlotIframeId, e => {
        return {
            w: Number(e.getAttribute("width")),
            h: Number(e.getAttribute("height"))
        };
    });

    if (JSON.stringify(adSlotSize) === JSON.stringify(expectedAdSlotSize)) {
        console.log('DFP slot does match with publisher config !');

        if (!isHbSlotAvailableEventTriggered) {
            console.log('Error: hbSlotAvailable tracking event has not been triggered');
            await screenshot(page, isSafeFrameTest, isTestPassed = false);
            process.exit(1);
        }

        if (!isImpressionEventTriggered) {
            console.log('Error: Impression tracking event has not been triggered');
            await screenshot(page, isSafeFrameTest, isTestPassed = false);
            process.exit(1);
        }

        if (!isStartEventTriggered) {
            console.log('Error: Start tracking event has not been triggered');
            await screenshot(page, isSafeFrameTest, isTestPassed = false);
            process.exit(1);
        }
        console.log("All tests passed !");
        await screenshot(page, isSafeFrameTest, isTestPassed = true);
        process.exit();
    }
    else {
        console.log('Error: DFP slot does not match with publisher config.');
        await screenshot(page, isSafeFrameTest, isTestPassed = false);
        process.exit(1);
    }
})();

async function screenshot(page, isSafeFrameTest, isTestPassed) {
    const prefix = isTestPassed ? 'success' : 'error';
    const prefixSafeFrame = isSafeFrameTest ? 'safeframe' : 'no-safeframe';
    await page.screenshot({
        path: `./screenshots/${prefix}-ad-slot-size-test-${prefixSafeFrame}-${new Date().getTime()}.png`,
        fullPage: true
    });
}
