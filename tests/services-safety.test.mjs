import assert from "node:assert/strict";
import { chmod, copyFile, mkdir, mkdtemp, readFile, readdir, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();

async function fixture(t) {
  const root = await mkdtemp(path.join(tmpdir(), "services-safety-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = path.join(root, "home");
  const agents = path.join(home, "Library/LaunchAgents");
  for (const dir of [agents, `${home}/bin`, `${home}/loaded`, `${root}/scripts`, `${root}/apps`]) {
    await mkdir(dir, { recursive: true });
  }
  // Redirect only the executable-existence check; the real relay never runs.
  const serviceScript = await readFile(`${repo}/scripts/services_mac.sh`, "utf8");
  await writeFile(`${root}/scripts/services_mac.sh`, serviceScript.replace("[ ! -x /usr/bin/nc ]", '[ ! -x "$HOME/bin/nc" ]'));
  // Override only the interactive UI, leaving the production safety flow intact.
  await writeFile(`${root}/scripts/utils.sh`, `${await readFile(`${repo}/scripts/utils.sh`, "utf8")}\nconfirm() { printf '%s\\n' "$1" >>"$HOME/prompts"; [ "$CONSENT" = yes ]; }\n`);
  for (const name of ["pbcopy", "pbpaste", "unifi-relay"]) {
    await copyFile(`${repo}/apps/${name}.plist`, `${root}/apps/${name}.plist`);
  }
  await writeFile(`${home}/bin/launchctl`, `#!/bin/sh
printf '%s\\n' "$*" >>"$HOME/calls"
case "$1" in
  print) test -f "$HOME/loaded/\${2##*/}" ;;
  bootstrap) name=\${3##*/}; touch "$HOME/loaded/localhost.\${name%.plist}" ;;
  bootout) rm -f "$HOME/loaded/\${2##*/}" ;;
  *) exit 1 ;;
esac
`);
  await chmod(`${home}/bin/launchctl`, 0o755);
  for (const [name, body] of Object.entries({
    nc: 'echo "unexpected nc execution" >&2; exit 99',
    lsof: 'printf "%s\\n" "$*" >>"$HOME/network-calls"; exit "${PORT_STATUS:-1}"',
  })) {
    await writeFile(`${home}/bin/${name}`, `#!/bin/sh\n${body}\n`);
    await chmod(`${home}/bin/${name}`, 0o755);
  }
  const run = (consent = "no", args = [], extraEnv = {}) => spawnSync("/bin/sh", [`${root}/scripts/services_mac.sh`, ...args], {
    env: { ...process.env, HOME: home, PATH: `${home}/bin:/usr/bin:/bin`, CONSENT: consent, ...extraEnv },
    encoding: "utf8", timeout: 10_000, input: "",
  });
  const calls = () => readFile(`${home}/calls`, "utf8").catch(() => "");
  return { root, home, agents, run, calls };
}

function ok(result) {
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

for (const consent of ["no", "yes"]) {
  test(`differing clipboard files require consent (${consent}) and preserve originals`, async (t) => {
    const { home, agents, run, calls } = await fixture(t);
    for (const name of ["pbcopy", "pbpaste"]) {
      await writeFile(`${agents}/${name}.plist`, `personal ${name}\n`);
      await writeFile(`${home}/loaded/localhost.${name}`, "");
    }
    ok(run(consent));
    const log = await calls();
    for (const name of ["pbcopy", "pbpaste"]) {
      if (consent === "no") {
        assert.equal(await readFile(`${agents}/${name}.plist`, "utf8"), `personal ${name}\n`);
        assert.doesNotMatch(log, new RegExp(`localhost\\.${name}`));
      } else {
        assert.equal(await readFile(`${agents}/${name}.plist`, "utf8"), await readFile(`${repo}/apps/${name}.plist`, "utf8"));
        assert.match(log, new RegExp(`bootout .*localhost\\.${name}`));
        assert.match(log, new RegExp(`bootstrap .*${name}\\.plist`));
        const backups = `${home}/.local/state/dotfiles/backups`;
        const originals = await Promise.all((await readdir(backups)).map((dir) => readFile(`${backups}/${dir}/${name}.plist`, "utf8").catch(() => null)));
        assert.ok(originals.includes(`personal ${name}\n`));
      }
    }
  });
}

test("byte-equal agents repair unloaded jobs without consent and rerun idempotently", async (t) => {
  const { home, agents, run, calls } = await fixture(t);
  for (const name of ["pbcopy", "pbpaste"]) {
    await copyFile(`${repo}/apps/${name}.plist`, `${agents}/${name}.plist`);
  }
  ok(run());
  assert.equal((await calls()).split("\n").filter((line) => line.startsWith("bootstrap ")).length, 2);
  await writeFile(`${home}/calls`, "");
  ok(run());
  assert.doesNotMatch(await calls(), /bootstrap|bootout/);
  await assert.rejects(readFile(`${home}/prompts`));
});

test("fresh clipboard agents remain opt-in", async (t) => {
  const { agents, run, calls } = await fixture(t);
  ok(run());
  assert.deepEqual(await readdir(agents), []);
  assert.equal(await calls(), "");
  ok(run("yes"));
  assert.equal((await calls()).split("\n").filter((line) => line.startsWith("bootstrap ")).length, 2);
});

test("confirmed replacement preserves a leaf symlink rather than overwriting its referent", async (t) => {
  const { root, home, agents, run } = await fixture(t);
  const outside = `${root}/precious`;
  await writeFile(outside, "untouched\n");
  await symlink(outside, `${agents}/pbcopy.plist`);
  ok(run("yes"));
  assert.equal(await readFile(outside, "utf8"), "untouched\n");
  const backups = `${home}/.local/state/dotfiles/backups`;
  const entries = await readdir(backups);
  assert.equal(entries.length, 1);
  assert.equal(await readlink(`${backups}/${entries[0]}/pbcopy.plist`), outside);
});

for (const destination of ["Library", "Library/LaunchAgents", ".local/state/dotfiles/backups"]) {
  test(`refuses physically escaping ${destination} before writes or launchctl`, async (t) => {
    const { root, home, agents, run, calls } = await fixture(t);
    const outside = `${root}/outside`;
    await mkdir(outside);
    const target = `${home}/${destination}`;
    if (destination.startsWith(".local")) {
      await mkdir(path.dirname(target), { recursive: true });
      await writeFile(`${agents}/pbcopy.plist`, "precious\n");
    } else {
      await rm(target, { recursive: true });
    }
    await symlink(outside, target);
    const result = run("yes");
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /Refusing/);
    assert.deepEqual(await readdir(outside), []);
    assert.equal(await calls(), "");
    if (destination.startsWith(".local")) assert.equal(await readFile(`${agents}/pbcopy.plist`, "utf8"), "precious\n");
  });
}

for (const definition of [null, "legacy launch agent\n", '<key>Label</key><string>localhost.herdr-tab-autoname</string>\n']) {
  test(`unproven legacy definition (${JSON.stringify(definition)}) is preserved without bootout`, async (t) => {
    const { home, agents, run, calls } = await fixture(t);
    const agent = `${agents}/herdr-tab-autoname.plist`;
    if (definition !== null) await writeFile(agent, definition);
    await writeFile(`${home}/loaded/localhost.herdr-tab-autoname`, "");
    const result = run();
    ok(result);
    assert.match(result.stdout, /Preserving unverified legacy/);
    assert.equal(await calls(), "");
    if (definition !== null) assert.equal(await readFile(agent, "utf8"), definition);
  });
}

for (const revision of ["7d20d5b", "acba407"]) {
  test(`proven historical ${revision} legacy agent is removed idempotently`, async (t) => {
    const { home, agents, run, calls } = await fixture(t);
    const agent = `${agents}/herdr-tab-autoname.plist`;
    await copyFile(`${repo}/tests/fixtures/herdr-tab-autoname-${revision}.plist`, agent);
    await writeFile(`${home}/loaded/localhost.herdr-tab-autoname`, "");
    ok(run());
    assert.match(await calls(), /bootout .*localhost\.herdr-tab-autoname/);
    await assert.rejects(readFile(agent));
    await writeFile(`${home}/calls`, "");
    ok(run());
    assert.equal(await calls(), "");
  });
}

test("UniFi plist uses loopback socket activation and bounded system nc", async () => {
  const xml = await readFile(`${repo}/apps/unifi-relay.plist`, "utf8");
  const clipboard = await readFile(`${repo}/apps/pbcopy.plist`, "utf8");
  assert.equal(xml, clipboard
    .replace("localhost.pbcopy", "localhost.unifi-relay")
    .replace("<string>/usr/bin/pbcopy</string>", ["/usr/bin/nc", "-G", "5", "192.168.1.1", "443"].map((arg) => `<string>${arg}</string>`).join("\n      "))
    .replace("<string>2224</string>", "<string>12443</string>"));
  if (process.platform === "darwin") {
    const result = spawnSync("plutil", ["-convert", "json", "-o", "-", `${repo}/apps/unifi-relay.plist`], { encoding: "utf8" });
    ok(result);
    assert.deepEqual(JSON.parse(result.stdout), {
      Label: "localhost.unifi-relay",
      ProgramArguments: ["/usr/bin/nc", "-G", "5", "192.168.1.1", "443"],
      inetdCompatibility: { Wait: false },
      Sockets: { Listeners: { SockServiceName: "12443", SockNodeName: "127.0.0.1" } },
    });
  }
});

test("relay is absent by default even with clipboard consent", async (t) => {
  const { home, agents, run, calls } = await fixture(t);
  ok(run("yes"));
  assert.deepEqual((await readdir(agents)).sort(), ["pbcopy.plist", "pbpaste.plist"]);
  assert.doesNotMatch(await calls(), /unifi/);
  await assert.rejects(readFile(`${home}/network-calls`));
});

test("relay opt-in still requires consent; installed relay is idempotent", async (t) => {
  const { home, agents, run, calls } = await fixture(t);
  ok(run("no", ["--unifi-relay"]));
  assert.deepEqual(await readdir(agents), []);
  ok(run("yes", ["--unifi-relay"]));
  assert.match(await calls(), /bootstrap .*unifi-relay.plist/);
  assert.equal(await readFile(`${agents}/unifi-relay.plist`, "utf8"), await readFile(`${repo}/apps/unifi-relay.plist`, "utf8"));
  await writeFile(`${home}/calls`, "");
  await writeFile(`${home}/network-calls`, "");
  ok(run("no", ["--unifi-relay"], { PORT_STATUS: "0" }));
  assert.doesNotMatch(await calls(), /bootstrap|bootout/);
  assert.equal(await readFile(`${home}/network-calls`, "utf8"), "");
});

for (const prior of ["fresh", "matching", "differing"]) {
  test(`occupied port refuses ${prior} unloaded relay without changes`, async (t) => {
    const { home, agents, run, calls } = await fixture(t);
    const agent = `${agents}/unifi-relay.plist`;
    if (prior === "matching") await copyFile(`${repo}/apps/unifi-relay.plist`, agent);
    if (prior === "differing") await writeFile(agent, "personal relay\n");
    const before = await readFile(agent, "utf8").catch(() => null);
    const result = run("yes", ["--unifi-relay"], { PORT_STATUS: "0" });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /12443 is occupied/);
    assert.match(result.stdout, /No listener was stopped/);
    assert.doesNotMatch(await calls(), /bootstrap|bootout|kill/);
    assert.equal(await readFile(agent, "utf8").catch(() => null), before);
    assert.equal(await readFile(`${home}/network-calls`, "utf8"), "-nP -iTCP:12443 -sTCP:LISTEN -t\n");
    await assert.rejects(readdir(`${home}/.local/state/dotfiles/backups`));
  });
}

test("unloaded matching relay is repaired after checking port", async (t) => {
  const { home, agents, run, calls } = await fixture(t);
  await copyFile(`${repo}/apps/unifi-relay.plist`, `${agents}/unifi-relay.plist`);
  ok(run("no", ["--unifi-relay"]));
  assert.match(await calls(), /bootstrap .*unifi-relay.plist/);
  assert.match(await readFile(`${home}/network-calls`, "utf8"), /12443/);
  assert.doesNotMatch(await readFile(`${home}/prompts`, "utf8"), /unifi-relay/);
});

for (const consent of ["no", "yes"]) {
  test(`differing loaded relay requires consent and backup (${consent})`, async (t) => {
    const { home, agents, run, calls } = await fixture(t);
    await writeFile(`${agents}/unifi-relay.plist`, "personal relay\n");
    await writeFile(`${home}/loaded/localhost.unifi-relay`, "");
    ok(run(consent, ["--unifi-relay"], { PORT_STATUS: "0" }));
    if (consent === "no") {
      assert.equal(await readFile(`${agents}/unifi-relay.plist`, "utf8"), "personal relay\n");
      assert.doesNotMatch(await calls(), /bootout|bootstrap/);
    } else {
      assert.match(await calls(), /bootout .*localhost.unifi-relay/);
      const backups = `${home}/.local/state/dotfiles/backups`;
      const entries = await readdir(backups);
      assert.equal(await readFile(`${backups}/${entries[0]}/unifi-relay.plist`, "utf8"), "personal relay\n");
    }
    await assert.rejects(readFile(`${home}/network-calls`));
  });
}

for (const tool of ["nc", "lsof", "launchctl"]) {
  test(`missing ${tool} refuses relay installation`, async (t) => {
    const { home, agents, run, calls } = await fixture(t);
    await rm(`${home}/bin/${tool}`);
    // Keep system tools available except the missing one; never fall back to
    // real launchctl or lsof on the host running these tests.
    for (const name of ["dirname", "id", "mkdir", "realpath"]) {
      await symlink(spawnSync("sh", ["-c", `command -v ${name}`], { encoding: "utf8" }).stdout.trim(), `${home}/bin/${name}`);
    }
    const result = run("yes", ["--unifi-relay"], { PATH: `${home}/bin` });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, new RegExp(`requires .*${tool}`));
    assert.deepEqual(await readdir(agents), []);
    assert.doesNotMatch(await calls(), /bootstrap|bootout/);
  });
}

test("lsof errors fail closed", async (t) => {
  const { agents, run, calls } = await fixture(t);
  const result = run("yes", ["--unifi-relay"], { PORT_STATUS: "2" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Could not check/);
  assert.deepEqual(await readdir(agents), []);
  assert.doesNotMatch(await calls(), /bootstrap|bootout/);
});

test("unknown arguments are rejected before all filesystem or service mutations", async (t) => {
  const { home, agents, run, calls } = await fixture(t);
  await rm(`${home}/Library`, { recursive: true });
  const result = run("yes", ["--unifi-relay", "--unknown"]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unknown argument: --unknown/);
  await assert.rejects(readdir(agents));
  assert.equal(await calls(), "");
  await assert.rejects(readFile(`${home}/network-calls`));
});
