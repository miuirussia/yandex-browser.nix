#!/usr/bin/env node

const { resolve } = require("path");
const { execSync } = require("child_process");
const { writeFile } = require("fs/promises");
const https = require("https");
const zlib = require("zlib");
const readline = require("readline");

const OUTPATH = resolve(process.env.OUTPATH || "meta");
const repoUrl = "https://repo.yandex.ru/yandex-browser/deb";

const packageUrls = [
  `${repoUrl}/dists/stable/main/binary-amd64/Packages.gz`,
  `${repoUrl}/dists/beta/main/binary-amd64/Packages.gz`,
];

async function fetchAndReadline(url) {
  const response = await new Promise((resolve) => https.get(url, resolve));
  return readline.createInterface({
    input: response.pipe(zlib.createGunzip()),
  });
}

const processUrl = async (packageUrl) => {
  const rl = await fetchAndReadline(packageUrl);
  const pkgData = {};

  for await (const line of rl) {
    const [key, value] = line.split(": ");
    if (key) pkgData[key] = value;
  }

  const { Package: pname, Version: version, Filename: path } = pkgData;
  const url = `${repoUrl}/${path}`;

  console.log(`Fetching ${url}...`);
  const hash = JSON.parse(
    String(execSync(`nix store prefetch-file --json '${url}'`))
  ).hash;

  const result = { pname, version, hash, url };

  writeFile(
    resolve(OUTPATH, `${pname}.json`),
    JSON.stringify(result, null, 2)
  );
};

packageUrls.map(processUrl)
