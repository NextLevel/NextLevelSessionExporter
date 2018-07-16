#!/bin/bash

# Docs by jazzy
# https://github.com/realm/jazzy
# ------------------------------

jazzy \
    --clean \
    --author 'Patrick Piemonte' \
    --author_url 'http://nextlevel.engineering' \
    --github_url 'https://github.com/NextLevel/NextLevelSessionExporter' \
    --sdk iphonesimulator \
    --xcodebuild-arguments -scheme,'Release' \
    --module 'SessionExporter' \
    --framework-root . \
    --readme README.md \
    --output docs/
