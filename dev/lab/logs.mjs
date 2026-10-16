import fs from 'node:fs';
import process from 'node:process';
import { Buffer } from 'node:buffer';

export async function followLog(file) {
  let position;
  const read = (start, end) => {
    const fd = fs.openSync(file, 'r');
    try {
      const chunks = [];
      for (let offset = start; offset < end;) {
        const buffer = Buffer.alloc(Math.min(65536, end - offset));
        const count = fs.readSync(fd, buffer, 0, buffer.length, offset);
        if (!count) {
          break;
        }
        chunks.push(buffer.subarray(0, count));
        offset += count;
      }
      return Buffer.concat(chunks).toString('utf8');
    } finally {
      fs.closeSync(fd);
    }
  };
  try {
    position = fs.statSync(file).size;
    const tail = read(Math.max(0, position - 65536), position).split(/\r?\n/);
    if (tail.at(-1) === '') {
      tail.pop();
    }
    process.stdout.write(`Following ${file}\nCtrl+C stops log viewing only; the lab keeps running.\n`);
    if (tail.length) {
      process.stdout.write(tail.slice(-40).join('\n') + '\n');
    }
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error(`Log does not exist: ${file}. Start that component once to create its log.`, { cause: error });
    }
    throw error;
  }
  await new Promise((resolve, reject) => {
    let changed;
    const stop = () => {
      fs.unwatchFile(file, changed);
      process.removeListener('SIGINT', stop);
      resolve();
    };
    changed = current => {
      try {
        if (current.nlink === 0) {
          return;
        }
        if (current.size < position) {
          position = 0;
        }
        if (current.size > position) {
          process.stdout.write(read(position, current.size));
          position = current.size;
        }
      } catch (error) {
        fs.unwatchFile(file, changed);
        process.removeListener('SIGINT', stop);
        reject(error);
      }
    };
    process.once('SIGINT', stop);
    fs.watchFile(file, { interval: 500 }, changed);
  });
}
