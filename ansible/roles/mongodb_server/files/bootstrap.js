// Idempotent: replica set + users. All secrets come from the container's environment.
const env = process.env;
const enc = encodeURIComponent;
const adm = connect(
  `mongodb://${enc(env.MONGO_INITDB_ROOT_USERNAME)}:${enc(env.MONGO_INITDB_ROOT_PASSWORD)}@127.0.0.1:27017/admin?directConnection=true`
);

// 1. Replica set
let initiated = true;
try {
  adm.adminCommand({ replSetGetStatus: 1 });
} catch (e) {
  if (e.code !== 94) throw e;      // 94 = NotYetInitialized
  initiated = false;
}
if (!initiated) {
  printjson(adm.adminCommand({
    replSetInitiate: { _id: env.RS_NAME, members: [{ _id: 0, host: env.RS_HOST }] }
  }));
  print('CHANGED: replica set initiated');
}
for (let i = 0; i < 30 && !adm.hello().isWritablePrimary; i++) sleep(1000);
if (!adm.hello().isWritablePrimary) throw new Error('no primary after 30s');

// 2. Users (passwords are re-applied from the vault on every run)
function ensureUser(dbName, user, pwd, roles) {
  const d = adm.getSiblingDB(dbName);
  if (d.getUser(user)) {
    d.updateUser(user, { pwd: pwd, roles: roles });
  } else {
    d.createUser({ user: user, pwd: pwd, roles: roles });
    print('CHANGED: created user ' + user);
  }
}
ensureUser(env.APP_DB, env.APP_USER, env.APP_PASSWORD, [{ role: 'readWrite', db: env.APP_DB }]);
ensureUser('admin', env.BACKUP_USER, env.BACKUP_PASSWORD, [{ role: 'backup', db: 'admin' }]);
ensureUser('admin', env.MONITOR_USER, env.MONITOR_PASSWORD,
  [{ role: 'clusterMonitor', db: 'admin' }, { role: 'read', db: 'local' }]);
print('OK');
