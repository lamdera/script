import * as util from 'util'
import { promises as fsp } from 'fs'

const runId = (new Date()).toISOString().replace(/T/g,'').replace(/:/g,'').replace(/\./g,'');
export const runLogPath = process.cwd() + `/run-${runId}.log`;
let runLogInfoPrinted = true;
let runLogQueue = Promise.resolve(''); // Global queue for writing to the run log atomically

writeRunLog('runLogPath: ' + runLogPath);
writeRunLog('runId: ' + runId);

// Internal functions

export async function log(entry: string, ...args: any[]): Promise<void> {
  const newArgs = args.map(a => { return util.inspect(a, {showHidden: false, depth: null, colors: true}); });
  console.log(entry, ...newArgs);
  const argsString = newArgs.length > 0 ? "\n" + newArgs.join("\n") : '';
  await writeRunLog(entry + argsString);
}

writeRunLog('DEBUG:' + process.env['DEBUG']);
const isDebug = process.env['DEBUG'] !== undefined || false;
writeRunLog('isDebug: ' + isDebug);

export async function logDebug(entry: string, ...args: any[]): Promise<void> {
  const newArgs = args.map(a => { return util.inspect(a, {showHidden: false, depth: null, colors: true}); });
  if (isDebug) console.log(entry, ...newArgs);
  const argsString = newArgs.length > 0 ? "\n" + newArgs.join("\n") : '';
  await writeRunLog('debug: ' + entry + argsString);
}

export async function writeRunLog(logEntry: string): Promise<string> {
  // console.log('writeRunLog: ' + logEntry, process.cwd());
  // Presumably this would be susceptible to race conditions, hence the queue...
  // if (!runLogInfoPrinted) {
  //   console.log(`runId:${runId}`);
  //   console.log(`runLog:${runLogPath}`);
  //   runLogInfoPrinted = true;
  // }

  runLogQueue = runLogQueue.then(async () => {
    await fsp.appendFile(runLogPath, logEntry + '\n');
    return logEntry + '\n';
  }).catch((err) => {
    console.error(err);
    return '';
  });
  return runLogQueue;
}

export function wrappedLog(identifier: string, err: any): void {
  // Frustratingly by default, logging an error uses .inspect which appears to truncate
  // long error lines based on terminal width. So instead we manually write out the error
  // in chunks based on terminal width, as the postgres failures are sometimes very long.
  writeRunLog('\n💥 wrappedLog:' + identifier + '\n');
  const str = err.message;
  const width = process.stdout.columns || 180;
  if (str == null || str === '') {
    writeRunLog('wrappedLog NullOrEmptyString error:' + typeof str + str);
    writeRunLog('wrappedLog NullOrEmptyString error:' + err);
    return;
  }
  for (let i = 0, charsLength = str.length; i < charsLength; i += width) {
    writeRunLog('\n' + str.substring(i, i + width));
  }
  // Seems we need to console.log as well to flush things? Infuriating...
  // console.log('');
}
