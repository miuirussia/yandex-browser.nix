#!/usr/bin/env node

const { resolve } = require('path');
const { execSync } = require('child_process');
const { writeFileSync } = require('fs');

const OUTPATH = resolve(process.env.OUTPATH || 'meta');

const repoUrl = "https://repo.yandex.ru/yandex-browser/deb";
const packageUrls = [
  `${repoUrl}/dists/stable/main/binary-amd64/Packages.gz`,
  `${repoUrl}/dists/beta/main/binary-amd64/Packages.gz`,
];

const processUrl = async url => {
  const response = await fetch(url);
  const data = await response.text();
  const pkgData = data.split('\n').reduce((acc, line) => {
    const [key, value] = line.split(': ');

    acc[key] = value;

    return acc;
  }, {});

  const pname = pkgData.Package;
  const version = pkgData.Version;
  const path = pkgData.Filename;
  const debUrl = `${repoUrl}/${path}`;

  console.log(`Fetching ${debUrl}...`);
  try {
    const hash = JSON.parse(String(execSync(`nix store prefetch-file --json '${debUrl}'`))).hash;

    const result_json = {
      pname,
      version,
      hash,
      url: debUrl,
    };

    writeFileSync(resolve(OUTPATH, `${pname}.json`), JSON.stringify(result_json));
  } catch (e) {
    console.error('Failed to fetch!', e);
  }
}

for (const url of packageUrls) {
  processUrl(url);
}
