const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
function protectFile(file) {
  if (process.platform !== 'win32') { fs.chmodSync(file, 0o600); return; }
  // Only this file: current account, workspace owner, SYSTEM and Administrators.
  // No global policy/ACL changes and no secret in the command or output.
  const quote = (value) => "'" + value.replaceAll("'", "''") + "'";
  const command = `$ErrorActionPreference='Stop'; $file=${quote(file)}; $root=${quote(root)}; ` +
    '$current=[Security.Principal.WindowsIdentity]::GetCurrent().User; ' +
    '$owner=(Get-Acl -LiteralPath $root).GetOwner([Security.Principal.SecurityIdentifier]); ' +
    '$expected=@($current,$owner,[Security.Principal.SecurityIdentifier]::new("S-1-5-18"),[Security.Principal.SecurityIdentifier]::new("S-1-5-32-544")); ' +
    '$allowed=@($expected | ForEach-Object {$_.Value} | Select-Object -Unique); $existing=Get-Acl -LiteralPath $file; ' +
    '$rules=@($existing.Access); $present=@(); $safe=$existing.AreAccessRulesProtected; ' +
    'foreach($entry in $rules) { $id=$entry.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value; $present+=$id; ' +
    'if($id -notin $allowed -or $entry.AccessControlType -ne "Allow" -or $entry.FileSystemRights -ne "FullControl") {$safe=$false}}; ' +
    'foreach($id in $allowed) {if($id -notin $present) {$safe=$false}}; if($safe) {exit 0}; ' +
    '$acl=New-Object Security.AccessControl.FileSecurity; $acl.SetAccessRuleProtection($true,$false); ' +
    'foreach($sid in $expected) {' +
    '$rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,"FullControl","Allow"); $acl.AddAccessRule($rule)}; ' +
    'Set-Acl -LiteralPath $file -AclObject $acl';
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', command], { encoding: 'utf8', windowsHide: true });
  if (result.status !== 0) throw new Error('Cannot restrict permissions of local credential/configuration file; no global permissions changed.');
}
function initialize() {
  const environment = path.join(root, '.env');
  let created = false;
  if (!fs.existsSync(environment)) {
    const template = fs.readFileSync(path.join(root, '.env.example'), 'utf8');
    if (!/^POSTGRES_PASSWORD=CHANGE_ME_LOCAL_ONLY\r?$/m.test(template)) throw new Error('Template must contain the documented local password marker.');
    const contents = template.replace(/^POSTGRES_PASSWORD=CHANGE_ME_LOCAL_ONLY\r?$/m,
      'POSTGRES_PASSWORD=' + crypto.randomBytes(32).toString('base64'));
    fs.writeFileSync(environment, contents, { flag: 'wx', mode: 0o600 });
    created = true;
  }
  if (!fs.lstatSync(environment).isFile() || fs.lstatSync(environment).isSymbolicLink()) throw new Error('Local environment must be a regular file.');
  const contents = fs.readFileSync(environment, 'utf8');
  for (const key of ['POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD']) {
    const entry = contents.match(new RegExp('^\\s*' + key + '\\s*=\\s*([^\\r\\n]*)', 'm'));
    const value = entry ? entry[1].trim().replace(/^(['"])(.*)\1$/, '$2').trim() : '';
    if (!value || value === 'CHANGE_ME_LOCAL_ONLY') throw new Error('Local environment contains a missing value or placeholder; existing file preserved.');
  }
  // Preserve the user's existing file and ACL. Restrict only a newly created file.
  if (created) protectFile(environment);
  console.log('Local .env ready; existing values preserved. No database password changed.');
}
if (require.main === module) {
  try { initialize(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { initialize };
