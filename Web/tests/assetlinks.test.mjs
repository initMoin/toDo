import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const expectedFingerprint =
  "1B:BB:2E:71:66:CE:BC:0A:C7:50:37:A0:B5:2C:3B:D3:E0:7D:0D:B7:2C:47:75:5B:03:4B:78:E3:0B:97:56:51";
const sha256FingerprintPattern = /^(?:[A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}$/;

test("publishes a valid Android Digital Asset Links declaration", async () => {
  const source = await readFile(
    new URL("../public/.well-known/assetlinks.json", import.meta.url),
    "utf8",
  );
  const declarations = JSON.parse(source);

  assert.ok(Array.isArray(declarations));
  assert.equal(declarations.length, 1);

  const [declaration] = declarations;
  assert.deepEqual(declaration.relation, [
    "delegate_permission/common.handle_all_urls",
    "delegate_permission/common.get_login_creds",
  ]);
  assert.equal(declaration.target.namespace, "android_app");
  assert.equal(declaration.target.package_name, "dev.iamshift.toDo.android");
  assert.deepEqual(declaration.target.sha256_cert_fingerprints, [expectedFingerprint]);
  assert.ok(
    declaration.target.sha256_cert_fingerprints.every((fingerprint) =>
      sha256FingerprintPattern.test(fingerprint),
    ),
  );
  assert.doesNotMatch(source, /REPLACE_WITH|dev\.iamshift\.todo\.android/);
});
