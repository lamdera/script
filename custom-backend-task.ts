import * as util from "util"
import * as ChildProcess from 'child_process'
const execProm = util.promisify(ChildProcess.exec)
import { promises as fsp } from 'fs'
import * as fsSync from 'fs';

import { getPorts } from './get-port';

import * as Postgres from './postgresql';

import { homedir } from 'os'
import { resolve, dirname } from "path"

import * as H from './helpers';

const homeDir = homedir();


export async function print(logEntry: string): Promise<string> {
  await H.log(logEntry);
  return logEntry;
}

export async function printDebug(logEntry: string): Promise<string> {
  await H.logDebug(logEntry);
  return logEntry;
}

export async function requireEnv(name: string): Promise<string> {
  const result = process.env[name];
  if (result) {
    return result;
  } else {
    throw `❌  requireEnv: No environment variable called ${name}

Available:

${Object.keys(process.env).join("\n")}
`;
  }
}

export async function readEnv(name: string): Promise<string | null> {
  const result = process.env[name];
  if (result) {
    return result;
  } else {
    return null;
  }
}

export async function environmentPlatform(name: string): Promise<string> {
  return process.platform;
}

export async function readFile(path: string): Promise<string> {
  try {
    const data = await fsp.readFile(resolvePath(path), 'utf8');
    H.logDebug(`👀 readFile: ${resolvePath(path)}`);
    return data;
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  readFile: Could not read ${path}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function writeFile({ path, contents }: { path: string, contents: string }): Promise<string> {
  try {
    const data = await fsp.writeFile(resolvePath(path), contents);
    H.logDebug(`✍️  writeFile: ${resolvePath(path)}`);
    return contents;
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  writeFile: Could not write ${path}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function appendFile({ path, contents }: { path: string, contents: string }): Promise<string> {
  try {
    const data = await fsp.appendFile(resolvePath(path), contents);
    H.logDebug(`✍️  appendFile: ${resolvePath(path)}`);
    return contents;
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  appendFile: Could not append ${path}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function touchFile({ path }: { path: string }): Promise<null> {
  try {
    const time = new Date();
    await fsp.utimes(resolvePath(path), time, time).catch(async function (err) {
      if (err.code !== 'ENOENT') {
          throw err;
      }
      let fh = await fsp.open(resolvePath(path), 'a');
      await fh.close();
      H.logDebug(`👆  touchFile: ${resolvePath(path)}`);
    });
    return null;
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  touchFile: Could not append ${resolvePath(path)}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function replaceInFile({ path, find, replace }: { path: string, find: string, replace: string }): Promise<string> {
  try {
    const newContents = await readFile(resolvePath(path)).then(contents => contents.replace(find, replace));
    H.logDebug(`🔁 replaceInFile: ${resolvePath(path)} (${find}) -> (${replace})`);
    await writeFile({ path: resolvePath(path), contents: newContents });
    return newContents;
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  replaceInFile: Could not replace in ${path}: ${err}

Searching for  ${find}
Replacing with ${replace}
Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function makeDirectory(path: string): Promise<string> {
  try {
    const data = await fsp.mkdir(resolvePath(path), { recursive: true });
    H.logDebug(`📂 makeDirectory ${resolvePath(path)}`);
    return "";
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  makeDirectory: Could not make directory ${path}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function makeDirectories(paths: string[]): Promise<string> {
   await Promise.all(paths.map(makeDirectory));
   return "";
}

export async function changeDirectory(path: string): Promise<string> {
  try {
    process.chdir(resolvePath(path));
    H.logDebug(`🚚 changeDirectory ${resolvePath(path)}`);
    return "";
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  changeDirectory: Could not change to directory ${path}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function currentDirectory(): Promise<string> {
  try {
    const cwd = process.cwd();
    H.logDebug(`👀 currentDirectory ${cwd}`);
    return cwd;
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  currentDirectory: Could not get currentDirectory: ${err}

Current working directory: ${cwd}
`);
  }
}

export async function remove(path: string): Promise<string> {
  try {
    const exists = await doesPathExist(resolvePath(path));
    if (!exists) return "";
    await fsp.rm(resolvePath(path), { recursive: true });
    H.logDebug(`🗑️  remove: ${resolvePath(path)}`);
    return "";
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  remove: Could not remove path ${path}: ${err}

Current working directory: ${cwd}
Resolved path: ${resolvePath(path)}
`);
  }
}

export async function removeAll(paths: string[]): Promise<string> {
  await Promise.all(paths.map(removeOrContinue));
  return "";
}

export async function removeOrContinue(path: string): Promise<string> {
  try {
    await fsp.rm(resolvePath(path), { recursive: true });
    H.logDebug(`🗑️  removeOrContinue: ${resolvePath(path)}`);
    return "";
  } catch (err) {
    H.logDebug(`🗑️  ⏭️  removeOrContinue: ${resolvePath(path)}`);
    return "";
  }
}

/*

Mimics the expected behaviour of cp on *nix systems

cp some/file.txt somedest -> somedest/file.txt
cp some/file.txt somedest/ -> somedest/file.txt
cp somesource somedest -> somedest/somesource      # copies the directory
cp somesource/ somedest -> somedest/*              # copies the contents of the directory
cp somesource/ somedest/ -> somedest/*             # copies the contents of the directory

*/
export async function copy({ src, dest }: { src: string, dest: string }): Promise<string> {
  try {
    const resolvedSrc = resolvePath(src);
    const resolvedDest = resolvePath(dest);
    const srcStat = await fsp.stat(resolvedSrc); // This also ensures our source exists
    const destStat: fsSync.Stats | null = await fsp.stat(resolvedDest).catch(() => null);

    if (srcStat.isFile()) {
      if (destStat && destStat.isDirectory()) {
        let destPath = resolvedDest + '/' + src.split('/').pop();
        if (resolvedDest.endsWith('/')) { destPath = resolvedDest + src.split('/').pop() }

        H.logDebug(`✍️  copy: ${resolvedSrc} -> ${destPath}`);
        await fsp.cp(resolvedSrc, destPath);
        return destPath;
      }

      // Otherwise we've already got a target filename, so use that
      H.logDebug(`✍️  copy: ${resolvedSrc} -> ${resolvedDest}`);
      await fsp.cp(resolvedSrc, resolvedDest, { recursive: true });
      return resolvedDest;

    } else if (dest.endsWith('/')) {
      // We're copying a directory, not its contents, so name it in the dest
      const srcDir = src.split('/').pop();
      const destPath = resolvedDest.endsWith(srcDir) ? resolvedDest : resolvedDest + '/' + src.split('/').pop();
      await fsp.mkdir(destPath, { recursive: true });
      H.logDebug(`✍️  copy: ${resolvedSrc} -> ${destPath}`);
      await fsp.cp(resolvedSrc, destPath, { recursive: true });
      return destPath;

    } else {
      H.logDebug(`✍️  copy: ${resolvedSrc} -> ${resolvedDest}`);
      await fsp.cp(resolvedSrc, resolvedDest, { recursive: true });
      return resolvedDest;
    }
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  copy: Could not copy ${src} to ${dest}: ${err}

Current working directory: ${cwd}
Resolved src: ${resolvePath(src)}
Resolved dest: ${resolvePath(dest)}
`);
  }
}

export async function move({ src, dest }: { src: string, dest: string }): Promise<string> {
  try {
    await fsp.rename(resolvePath(src), resolvePath(dest));
    H.logDebug(`✂️  move: ${resolvePath(src)} -> ${resolvePath(dest)}`);
    return "";
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  move: Could not move ${src} to ${dest}: ${err}

Current working directory: ${cwd}
Resolved src: ${resolvePath(src)}
Resolved dest: ${resolvePath(dest)}
`);
  }
}

export async function symlink({ src, dest }: { src: string, dest: string }): Promise<string> {
  try {
    await fsp.symlink(resolvePath(src), resolvePath(dest));
    H.logDebug(`🔗  symlink: ${resolvePath(src)} -> ${resolvePath(dest)}`);
    return resolvePath(dest);
  } catch (err) {
    const cwd = process.cwd();
    throw new Error(`❌  symlink: Could not symlink ${src} to ${dest}: ${err}

Current working directory: ${cwd}
Resolved src: ${resolvePath(src)}
Resolved dest: ${resolvePath(dest)}
    `);
  }
}

export async function homeDirectory(): Promise<string> {
  try {
    H.logDebug(`🏠  homeDirectory`);
    return homedir();
  } catch (err) {
    const cwd = process.cwd();
    // Is this even possible as an error?
    throw new Error(`❌  homeDirectory: Could not get home directory: ${err}

Current working directory: ${cwd}
`);
  }
}

export async function doesPathExist(path: string): Promise<boolean> {
  try {
    const data = await fsp.stat(resolvePath(path));
    H.logDebug(`🔎  ✅  doesPathExist: ${path} `);
    return true;
  } catch (err) {
    H.logDebug(`🔎  ❌  doesPathExist: ${path} `);
    return false;
  }
}


export async function getFreePort(): Promise<number> {
  try {
    const freePort = await getPorts();
    return freePort;
  } catch (err) {
    throw new Error(`getFreePort: Could not get port: ${err}`);
  }
}

// This can be done manually by calling exec or execStream
// export async function bash(command: string): Promise<ExecResult> {
//   return exec({ bin: 'bash', args: ['-c', command] });
// }

type ExecResult = { exitCode: number, stdout: string, stderr: string };

export async function exec(p: { bin: string, args: string[] }): Promise<ExecResult> {
  const { bin, args } = p;
  H.logDebug(`🤖 exec: ${resolvePath(bin)} ${args.map(resolvePath).join(" ")}`);
  const res = await execA(resolvePath(bin), args.map(resolvePath)).catch((error) => {
    H.logDebug('❌❌❌❌ exec error', error);
    process.exit();
  });
  // H.log(`res:`, res);
  return res;
}

async function execA(bin: string, args: string[]): Promise<ExecResult> {
  let result;
  // H.logDebug(`execA running ${bin} ${args}`);
  try {
    // result = await execProm(bin + ' ' + args.join(" "), {}, (err, stdout, stderr) => {
    //   if (err) { console.error(err); return; }
    //   if (stderr) console.warn(stderr);
    //   if (stdout) H.log(stdout);
    //   H.log('HEEEEERE', err, { exitCode: err?.code ?? 0, stdout, stderr });
    //   return { exitCode: err?.code ?? 0, stdout, stderr };
    // }).catch((err: ExecResult) => {
    //   H.log('❌❌❌❌ exec error', err);
    //   return err;
    // });
    result = await execProm(bin + ' ' + args.join(" ")).catch((err: ExecResult) => {
      H.logDebug('❌❌❌❌ exec error', err);
      return err;
    });
    // H.logDebug('ending`!!!!', result)
    // execProm doesn't give us an exitCode on success, so we presume 0
    // @TODO this is obviously wrong
    result.exitCode = 0;
  } catch(ex) {
    // Shouldn't be possible but it is JS after all
    H.logDebug('❌❌❌❌ impossible error', ex);
    throw Error(ex);
  }
  return result;
}

export async function execStreamQuiet(params: { bin: string, args: string[] }): Promise<ExecResult> {
  return execStream(params, false);
}

export async function execStream(params: { bin: string, args: string[] }, printOutput: boolean = true): Promise<ExecResult> {
  return new Promise(resolve => {
    const { bin, args } = params;
    let stdout = '';
    let stderr = '';

    H.logDebug(`🤖🚰 execStream: ${resolvePath(bin)} ${args.map(resolvePath).join(" ")}`);
    const p = ChildProcess.spawn(resolvePath(bin), args.map(resolvePath), {
      cwd: process.cwd(),
      env: process.env
    });

    p.stdout.on('data', function (data) {
      if (printOutput) {
        H.log(data.toString());
      } else {
        H.logDebug(data.toString());
      }
      stdout += data.toString();
    });

    p.stderr.on('data', function (data) {
      if (printOutput) {
        H.log(data.toString());
      } else {
        H.logDebug(data.toString());
      }
      stderr += data.toString();
    });

    p.on('exit', function (code, signal) {
      if (code == 0 ) {
        H.logDebug(`✅ execStream: ${bin} exited with code ${code.toString()} and signal ${signal}`);
      } else {
        H.logDebug(`❌ execStream: ${bin} exited with code ${code.toString()} and signal ${signal}`);
      }
      return resolve({ exitCode: code, stdout, stderr });
    });

    p.on('error', function (error) {
      H.logDebug(`❌ execStream: ${bin} encountered an error ${error}`);
      return resolve({ exitCode: null, stdout, stderr });
    });

    p.on('close', function (code, signal) {
      H.logDebug(`❌ execStream: ${bin} closed with code ${code} and signal ${signal}`);
    });
  });
}

async function execRaw(command: string): Promise<ExecResult> {
  let result;
  try {
    result = await execProm(command).catch((err: ExecResult) => {
      return err;
    });
    // execProm doesn't give us an exitCode on success, so we presume 0
    result.exitCode = 0;
  } catch(ex) {
    // Shouldn't be possible but it is JS after all
    throw Error(ex);
  }
  return result;
}

/**
 * Run a shell command in a completely detached process that may live on after the parent process dies.
 * Returns the PID of the detached process.
 */
export async function execDetached(params: { bin: string, args: string[] }): Promise<number> {
  H.logDebug(`🤖🧟‍♀️ execDetached: ${resolvePath(params.bin)} ${params.args.map(resolvePath).join(" ")}`);

  const sout = await fsp.open(H.runLogPath + '-spawn', 'a') as any;
  const serr = await fsp.open(H.runLogPath + '-spawn', 'a') as any;
  process.on('exit', async () => {
    // @TODO is there a reason these couldn't just be inline after the unref() ?
    fsSync.closeSync(sout);
    fsSync.closeSync(serr);
  });

  const child = ChildProcess.spawn(params.bin, params.args, {
    detached: true,
    // stdio: 'ignore'
    stdio: ['ignore', sout, serr]
  });
  child.unref();
  return child.pid;
}

function resolvePath(path: string): string {
  if (!path) return path;
  // H.log('trying to resolve path', path);
  if (path.match(/^~\//)) return path.replace(/^~/, homeDir);
  return path;
}

export async function exit(): Promise<void> {
  H.logDebug('🏁 exit');
  process.exit();
}

export async function die(code: number): Promise<void> {
  H.logDebug(`💀 die: ${code}`);
  process.exit(code);
}

export async function sleep(ms: number): Promise<void> {
  return new Promise(r => setTimeout(r, ms));
}

export async function postgresRawQuery(data: { sql: string }): Promise<any> {
  H.logDebug(`💿  postgresRawQuery:`, data);
  const str = await Postgres.db.raw(data.sql).then((result: any) => {
    H.logDebug('results was', result);
    if (result.length > 0) {
      const rows = result.filter((row: any) => row.command === 'SELECT')[0];
      H.logDebug('rows', rows);
      if (rows?.rows) return JSON.stringify(rows.rows);
      return JSON.stringify(result);
    } else {
      return JSON.stringify(result.rows);
    }

  }).catch(err => {
    H.logDebug('postgresRawQuery', err);
    Postgres.cleanup();
    throw Error(err);
  });
  return str;
}

export async function postgresRawQueryJSON(data: { sql: string }): Promise<any> {
  H.logDebug(`💿  postgresRawQueryJSON:`, data);
  const str = await Postgres.db.raw(data.sql).then((result: any) => {
    // H.logDebug('results was', result);
    if (result.length > 0) {
      const rows = result.filter((row: any) => row.command === 'SELECT')[0];
      // H.logDebug('rows', rows.rows);
      return rows.rows;
    } else {
      // H.logDebug('rows', result.rows);
      return result.rows;
    }
  }).catch(err => {
    H.logDebug('postgresRawQuery', err);
    Postgres.cleanup();
    throw Error(err);
  });
  return str;
}