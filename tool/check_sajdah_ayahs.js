#!/usr/bin/env node

const https = require('https');

const SAJDAH_KEYS = [
  '7:206',
  '13:15',
  '16:50',
  '17:109',
  '19:58',
  '22:18',
  '22:77',
  '25:60',
  '27:26',
  '32:15',
  '38:24',
  '41:38',
  '53:62',
  '84:21',
  '96:19',
];

function fetchVerse(verseKey) {
  return new Promise((resolve, reject) => {
    const url = `https://api.quran.com/api/v4/verses/by_key/${verseKey}?language=ar&words=true&word_fields=text_uthmani,text_uthmani_tajweed,tajweed,char_type_name`;
    https
      .get(url, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            const words = parsed?.verse?.words ?? [];
            const firstWord = words.find((w) => w?.char_type_name !== 'end');
            const text = (firstWord?.text_uthmani || '').trim();
            if (!text) {
              reject(new Error(`${verseKey}: missing first word in API payload`));
              return;
            }
            resolve({ verseKey, firstWord: text });
          } catch (err) {
            reject(new Error(`${verseKey}: invalid JSON response (${err.message})`));
          }
        });
      })
      .on('error', (err) => {
        reject(new Error(`${verseKey}: network error (${err.message})`));
      });
  });
}

async function main() {
  const failures = [];

  for (const key of SAJDAH_KEYS) {
    try {
      const result = await fetchVerse(key);
      console.log(`OK ${result.verseKey}\t${result.firstWord}`);
    } catch (err) {
      failures.push(err.message);
      console.error(`FAIL ${err.message}`);
    }
  }

  console.log('');
  if (failures.length === 0) {
    console.log('ALL_SAJDAH_FIRST_WORDS_PRESENT');
    process.exit(0);
  }

  console.error(`SAJDAH_CHECK_FAILED (${failures.length})`);
  process.exit(1);
}

main();
