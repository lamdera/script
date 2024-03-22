import * as url from 'url';
import * as fs from 'fs';

// import pg from 'pg';
// import type { Pool } from 'pg';
import knex from  'knex';

import * as dotenv from 'dotenv';
dotenv.config();

//Parse method copied from https://github.com/brianc/node-postgres
//Copyright (c) 2010-2014 Brian Carlson (brian.m.carlson@gmail.com)
//MIT License

//parses a connection string
function parse(str) {
  //unix socket
  if (str.charAt(0) === '/') {
    var config = str.split(' ')
    return { host: config[0], database: config[1] }
  }

  // url parse expects spaces encoded as %20
  var result = url.parse(
    / |%[^a-f0-9]|%[a-f0-9][^a-f0-9]/i.test(str) ? encodeURI(str).replace(/\%25(\d\d)/g, '%$1') : str,
    true
  )
  var config: any = result.query
  for (var k in config) {
    if (Array.isArray(config[k])) {
      config[k] = config[k][config[k].length - 1]
    }
  }

  var auth = (result.auth || ':').split(':')
  config.user = auth[0]
  config.password = auth.splice(1).join(':')

  config.port = result.port
  if (result.protocol == 'socket:') {
    config.host = decodeURI(result.pathname)
    config.database = result.query.db
    config.client_encoding = result.query.encoding
    return config
  }
  if (!config.host) {
    // Only set the host if there is no equivalent query param.
    config.host = result.hostname
  }

  // If the host is missing it might be a URL-encoded path to a socket.
  var pathname = result.pathname
  if (!config.host && pathname && /^%2f/i.test(pathname)) {
    var pathnameSplit = pathname.split('/')
    config.host = decodeURIComponent(pathnameSplit[0])
    pathname = pathnameSplit.splice(1).join('/')
  }
  // result.pathname is not always guaranteed to have a '/' prefix (e.g. relative urls)
  // only strip the slash if it is present.
  if (pathname && pathname.charAt(0) === '/') {
    pathname = pathname.slice(1) || null
  }
  config.database = pathname && decodeURI(pathname)

  if (config.ssl === 'true' || config.ssl === '1') {
    config.ssl = true
  }

  if (config.ssl === '0') {
    config.ssl = false
  }

  if (config.sslcert || config.sslkey || config.sslrootcert || config.sslmode) {
    config.ssl = {}
  }

  if (config.sslcert) {
    config.ssl.cert = fs.readFileSync(config.sslcert).toString()
  }

  if (config.sslkey) {
    config.ssl.key = fs.readFileSync(config.sslkey).toString()
  }

  if (config.sslrootcert) {
    config.ssl.ca = fs.readFileSync(config.sslrootcert).toString()
  }

  switch (config.sslmode) {
    case 'disable': {
      config.ssl = false
      break
    }
    case 'prefer':
    case 'require':
    case 'verify-ca':
    case 'verify-full': {
      break
    }
    case 'no-verify': {
      config.ssl.rejectUnauthorized = false
      break
    }
  }

  return config
}



// const parse = PgConnStr.default;
type PgUrl = ReturnType<typeof parse>;
// console.log(PgConnStr.default);
// console.log(PgConnStr.parse);

export function requireVar(name: string): string {
  const envVar = process.env[name] || null;
  if (!envVar) {
    throw Error(`ENV var ${name} must be defined`);
  } else if (envVar === '') {
    throw Error(`ENV var ${name} was defined, but was empty`);
  }
  return envVar;
}

export const ENVS = {
  development: 'development',
  preview    : 'preview',
  production : 'production'
};
export type Env = keyof typeof ENVS;
export const mode = (process.env.NODE_ENV || 'development').toLowerCase() as Env;

// export const pool: Pool = new pg.Pool(
//   {
//     connectionString: requireVar('DATABASE_URL'),
//     ssl: mode == 'development' ? false : { rejectUnauthorized : false } ,
//     options: '-c TimeZone=utc',
//   }
// );


type ConnectionConfig = {
  host    : string,
  port    : number,
  user    : string,
  password: string,
  database: string,
  ssl     : boolean,
  charset : string,
  timezone: string,
  createRetryIntervalMillis: number
}

declare type Maybe<T> = T | null | undefined;
const dbAndEnv = process.env.DB_NAME ? `${process.env.DB_NAME}_${mode}` : void(0);
const dbHost   = (urlConfig: Maybe<PgUrl>) => (urlConfig?.host || process.env.DB_HOST || '127.0.0.1').toLowerCase();

const databaseUrl = requireVar('DATABASE_URL');
// console.log(parse(databaseUrl));

// env.DATABASE_URL takes precedence.
export function connectionConfig(): ConnectionConfig {
  let urlConfig;
  // console.log('the database url is', databaseUrl);
  // Heroku PG uses a pg connection string - parse it and only enforce SSL in heroku hosted environments
  if(databaseUrl) {
    urlConfig       = parse(databaseUrl) as any;
    const isLocalDB = [ 'localhost', '127.0.0.1', '0.0.0.0' ].includes(dbHost(urlConfig));
    urlConfig.ssl   = isLocalDB ? false : { rejectUnauthorized: false } ;
  }

  const connection = {
    host    : dbHost(urlConfig),
    port    : Number(urlConfig?.port || process.env.DB_PORT),
    user    : urlConfig?.user        || process.env.DB_USER || dbAndEnv,
    password: urlConfig?.password    || process.env.DB_PASS || '',
    database: urlConfig?.database    || dbAndEnv,
    ssl     : urlConfig?.ssl         || false,
    charset : 'utf8',
    timezone: 'utc',
    createRetryIntervalMillis: 200
  };

  return connection;
}

export const dbConfig = {
  debug: false, //env === ENVS.development,
  client: 'pg',
  pool: {
    min: 0,
    max: 10,
    afterCreate: function(connection: any, callback: any) {
      connection.query('set timezone=\'utc\';', function(err: any) {
        callback(err, connection);
      });
    }
  },
  connection: connectionConfig()
};

export const db = knex(dbConfig);

export const cleanup = async function() {
  await db.destroy();
};

export function wrapPromiseMain(m: NodeModule, entryPoint: any): void {
  if (require.main !== m) {
    // console.log('⏭  not main, skipping wrapPromiseMain exec', m.id);
    return;
  }

  const pollTime = 1000000;
  const interval = setInterval(() => { 0; }, pollTime);

  return entryPoint().then(async () => {
    clearInterval(interval);
    console.log('cleaning up!');
    await cleanup();
  });
}