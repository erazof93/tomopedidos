const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
function fixture() {
  const cache = path.resolve(__dirname, '../.cache');
  fs.mkdirSync(cache, { recursive: true });
  const root = fs.mkdtempSync(path.join(cache, 'env-test-'));
  fs.mkdirSync(path.join(root, 'scripts'));
  fs.copyFileSync(path.join(__dirname, 'init-local-db.cjs'), path.join(root, 'scripts/init-local-db.cjs'));
  fs.writeFileSync(path.join(root, '.env.example'), 'POSTGRES_DB=tomopedidos_local\nPOSTGRES_USER=tomopedidos_bootstrap\nPOSTGRES_PASSWORD=CHANGE_ME_LOCAL_ONLY\nPOSTGRES_PORT=55432\n');
  return root;
}
function run(root) { return spawnSync(process.execPath, [path.join(root, 'scripts/init-local-db.cjs')], { encoding: 'utf8', windowsHide: true }); }
test('new .env has a generated password, is preserved on retry and has no legacy dependencies', () => {
  const root = fixture();
  const first = run(root);
  assert.ok(first.status === 0, 'initialization failed');
  const file = path.join(root, '.env');
  const original = fs.readFileSync(file);
  const password = original.toString().match(/^POSTGRES_PASSWORD=(.+)$/m)[1];
  assert.ok(Buffer.from(password, 'base64').length === 32, 'password entropy source size incorrect');
  assert.ok(!first.stdout.includes(password), 'password exposed');
  assert.ok(run(root).status === 0, 'repeated initialization failed');
  assert.ok(fs.readFileSync(file).equals(original), 'configuration changed on retry');
  assert.ok(!fs.existsSync(path.join(root, '.env.local')) && !fs.existsSync(path.join(root, '.local')), 'legacy files created');
});
test('existing configured .env wins over legacy .env.local and is never rewritten', () => {
  const root = fixture();
  const original = 'POSTGRES_DB=tomopedidos_local\nPOSTGRES_USER=tomopedidos_bootstrap\nPOSTGRES_PASSWORD=TEST_FIXTURE_ONLY\n';
  fs.writeFileSync(path.join(root, '.env'), original);
  fs.writeFileSync(path.join(root, '.env.local'), 'legacy-preserve');
  assert.ok(run(root).status === 0, 'existing configuration rejected');
  assert.ok(fs.readFileSync(path.join(root, '.env'), 'utf8') === original, 'existing configuration overwritten');
  assert.ok(fs.readFileSync(path.join(root, '.env.local'), 'utf8') === 'legacy-preserve', 'legacy configuration changed');
});
test('placeholder or missing password is rejected without rewriting existing configuration', () => {
  for (const content of ['POSTGRES_DB=local\nPOSTGRES_USER=local\nPOSTGRES_PASSWORD=CHANGE_ME_LOCAL_ONLY\n', 'POSTGRES_DB=local\nPOSTGRES_USER=local\n']) {
    const root = fixture();
    fs.writeFileSync(path.join(root, '.env'), content);
    assert.ok(run(root).status !== 0, 'invalid existing configuration accepted');
    assert.ok(fs.readFileSync(path.join(root, '.env'), 'utf8') === content, 'invalid configuration overwritten');
  }
});
test('directory at .env is rejected and preserved', () => {
  const root = fixture();
  fs.mkdirSync(path.join(root, '.env'));
  assert.ok(run(root).status !== 0, 'directory accepted');
  assert.ok(fs.statSync(path.join(root, '.env')).isDirectory(), 'directory removed');
});
