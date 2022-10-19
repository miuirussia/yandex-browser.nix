#!/usr/bin/env node

const { resolve } = require('path');
const { execSync } = require('child_process');
const { readFileSync, writeFileSync } = require('fs');

const OUTPATH = resolve(process.env.OUTPATH || 'meta');

const CODECS_JSON = "https://browser-resources.s3.yandex.net/linux/codecs.json";

const getPath = (path, dir) => resolve(`${path}/opt/yandex/${dir}/update-ffmpeg`);

const BROWSERS = [
  ['yandex-browser-stable', process.env.STABLE, 'browser'],
  ['yandex-browser-beta', process.env.BETA, 'browser-beta'],
];

const main = async () => {
  try {
    const data = JSON.parse(String(execSync(`curl -s '${CODECS_JSON}'`)).trim());

    for (const [name, path, dir] of BROWSERS) {
      try {
        const [, shortVersion] = String(readFileSync(getPath(path, dir))).match(/jq -r '\."([\d.]*)"\[\]\?'/);
        const url = data[shortVersion][0];
        const [version] = url.match(/\d*\.\d*\.\d*\.\d*/);
        const hash = JSON.parse(String(execSync(`nix store prefetch-file --json '${url}'`))).hash;

        const result_json = { url, version, hash };

        writeFileSync(resolve(OUTPATH, `${name}-codecs.json`), JSON.stringify(result_json));
      } catch (e) {
        console.error(`Failed get codecs from ${name}`, e);
      }
    }
  } catch (e) {
    console.error('Failed get codecs', e);
  }
};

main();

