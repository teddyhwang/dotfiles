import assert from "node:assert/strict";
import { mkdir, mkdtemp, realpath, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const script = path.join(process.cwd(), "home/local/bin/zed-other-file");

async function project(t, existing = []) {
  const root = await realpath(await mkdtemp(path.join(os.tmpdir(), "zed-other-file-")));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const file of existing) {
    await mkdir(path.dirname(path.join(root, file)), { recursive: true });
    await writeFile(path.join(root, file), "");
  }
  return root;
}

function other(root, file, ...flags) {
  return spawnSync("python3", [script, ...flags, path.join(root, file)], {
    encoding: "utf8",
    cwd: root,
  });
}

function assertOther(root, file, expected) {
  const result = other(root, file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `${path.join(root, expected)}\n`);
}

test("rails source prefers the existing test over missing candidates", async (t) => {
  const root = await project(t, ["app/models/user.rb", "test/models/user_test.rb"]);
  assertOther(root, "app/models/user.rb", "test/models/user_test.rb");
});

test("rails test goes back to the source file", async (t) => {
  const root = await project(t, ["app/models/user.rb", "test/models/user_test.rb"]);
  assertOther(root, "test/models/user_test.rb", "app/models/user.rb");
});

test("rails model finds the pluralized factory through transformers", async (t) => {
  const root = await project(t, ["app/models/user.rb", "spec/factories/users.rb"]);
  assertOther(root, "app/models/user.rb", "spec/factories/users.rb");
});

test("rails controller expands globs to existing views", async (t) => {
  const root = await project(t, ["app/controllers/users_controller.rb", "app/views/users/index.html.erb"]);
  const result = other(root, "app/controllers/users_controller.rb", "--all");
  assert.equal(result.status, 0, result.stderr);
  assert.ok(
    result.stdout.split("\n").includes(`view\t${path.join(root, "app/views/users/index.html.erb")}\texists`),
    result.stdout,
  );
});

test("component lib files map to the component test directory and back", async (t) => {
  const source = "components/foo/lib/bar/baz.rb";
  const test_ = "components/foo/test/lib/bar/baz_test.rb";
  const root = await project(t, [source, test_]);
  assertOther(root, source, test_);
  assertOther(root, test_, source);
});

test("Folder/Folder.tsx maps to Folder/tests/Folder.test.tsx and back", async (t) => {
  const root = await project(t, ["Folder/Folder.tsx", "Folder/tests/Folder.test.tsx"]);
  assertOther(root, "Folder/Folder.tsx", "Folder/tests/Folder.test.tsx");
  assertOther(root, "Folder/tests/Folder.test.tsx", "Folder/Folder.tsx");
});

test("dir/file.ts maps to dir/tests/file.test.ts and back", async (t) => {
  const root = await project(t, ["dir/file.ts", "dir/tests/file.test.ts"]);
  assertOther(root, "dir/file.ts", "dir/tests/file.test.ts");
  assertOther(root, "dir/tests/file.test.ts", "dir/file.ts");
});

test("react components map to sibling test files and back", async (t) => {
  const root = await project(t, ["src/foo.tsx", "src/foo.test.tsx"]);
  assertOther(root, "src/foo.tsx", "src/foo.test.tsx");
  assertOther(root, "src/foo.test.tsx", "src/foo.tsx");
});

test("with only missing candidates the first match is chosen", async (t) => {
  const root = await project(t, ["src/foo.tsx"]);
  assertOther(root, "src/foo.tsx", "src/foo.test.tsx");

  const all = other(root, "src/foo.tsx", "--all");
  assert.equal(all.status, 0, all.stderr);
  assert.equal(all.stdout, `test\t${path.join(root, "src/foo.test.tsx")}\tnew\n`);
});

test("--all lists existing matches first with context and status", async (t) => {
  const root = await project(t, ["dir/file.ts", "dir/tests/file.test.ts"]);
  const result = other(root, "dir/file.ts", "--all");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trimEnd().split("\n"), [
    `test\t${path.join(root, "dir/tests/file.test.ts")}\texists`,
    `test\t${path.join(root, "dir/file.test.ts")}\tnew`,
  ]);
});

test("relative paths resolve against the current directory", async (t) => {
  const root = await project(t, ["src/foo.tsx", "src/foo.test.tsx"]);
  const result = spawnSync("python3", [script, "src/foo.tsx"], { encoding: "utf8", cwd: root });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `${path.join(root, "src/foo.test.tsx")}\n`);
});

test("files without alternates exit 1", async (t) => {
  const root = await project(t, ["notes.txt"]);
  for (const flags of [[], ["--all"]]) {
    const result = other(root, "notes.txt", ...flags);
    assert.equal(result.status, 1);
    assert.equal(result.stdout, "");
    assert.equal(result.stderr, "No alternate files found\n");
  }
});
