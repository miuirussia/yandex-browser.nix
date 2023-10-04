#!/usr/bin/env node
const { resolve } = require('path');
const { execSync, spawn } = require('child_process');
const { readFileSync, writeFileSync } = require('fs');

const OUTPATH = resolve(process.env.OUTPATH || 'meta');

const CODECS_JSON = "https://browser-resources.s3.yandex.net/linux/codecs_snap.json";

const getPath = (path, dir) => resolve(`${path}/opt/yandex/${dir}/yandex_browser`);

const BROWSERS = [
  ['yandex-browser-stable', process.env.STABLE, 'browser'],
  ['yandex-browser-beta', process.env.BETA, 'browser-beta'],
];

const main = async () => {
  try {
    const data = JSON.parse(String(execSync(`curl -s '${CODECS_JSON}'`)).trim());

    for (const [name, path, dir] of BROWSERS) {
      const proc = spawn('strings', [getPath(path, dir)]);
      proc.stdout.on("data", chunk => {
        const result = /Chrome\/(\d+\.\d+\.\d+\.\d+)/.exec(chunk.toString());
        if (result) {
          try {
            const chromeVersion = result[1];
            const [majorChromeVersion] = chromeVersion.split('.');
            const { url, path } = data[majorChromeVersion];
            const hash = JSON.parse(String(execSync(`nix store prefetch-file --json '${url}'`))).hash;

            const resultJson = { url, path, version: chromeVersion, hash };

            writeFileSync(resolve(OUTPATH, `${name}-codecs.json`), JSON.stringify(result_json));
          } catch (e) {
            console.error(`Failed get codecs from ${name}`, e);
          }
        } else {
          console.error(`Failed get codecs from ${name}: No chrome version detected`);
        }
      });
    }
  } catch (e) {
    console.error('Failed get codecs', e);
  }
};

main();
