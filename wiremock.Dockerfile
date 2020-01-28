FROM REGISTRY_URL_INJECTED_BY_TEST_SH/wiremock:2.8.0_0.18

EXPOSE 8443

ENTRYPOINT ["java", "-Dfile.encoding=UTF-8", "-cp", "wiremock-extensions.jar:wiremock.jar", "com.github.tomakehurst.wiremock.standalone.WireMockServerRunner", "--extensions", "tv.teads.wiremock.extension.JsonExtractor,tv.teads.wiremock.extension.FreeMarkerRenderer", "--https-port", "8443"]
