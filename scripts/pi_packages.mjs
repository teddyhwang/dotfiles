// Provision personal Pi packages without replacing machine-local configuration.

import { randomBytes } from "node:crypto";
import {
  accessSync, closeSync, constants, existsSync, fsyncSync, lstatSync, mkdirSync, mkdtempSync,
  openSync, readFileSync, readlinkSync, renameSync, statSync, symlinkSync, unlinkSync,
  writeFileSync, writeSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { isDeepStrictEqual } from "node:util";

class ProvisionError extends Error {}

const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isStringList = (value) => Array.isArray(value) && value.every((x) => typeof x === "string");

// Mirror pathlib: join components, dropping empty and "." parts but keeping "..".
function join(...parts) {
  const joined = parts.join("/");
  const kept = joined.split("/").filter((part) => part !== "" && part !== ".");
  return (joined.startsWith("/") ? "/" : "") + kept.join("/");
}

// Mirror Path.resolve() (non-strict): follow symlinks as far as they exist,
// including dangling ones, and keep any non-existent remainder lexically.
function resolvePath(input) {
  const queue = input.split("/");
  let resolved = "/";
  let links = 0;
  while (queue.length) {
    const name = queue.shift();
    if (!name || name === ".") continue;
    if (name === "..") {
      resolved = path.dirname(resolved);
      continue;
    }
    const next = resolved === "/" ? `/${name}` : `${resolved}/${name}`;
    let isLink = false;
    try {
      isLink = lstatSync(next).isSymbolicLink();
    } catch {
      // Missing or inaccessible components are kept lexically.
    }
    if (!isLink) {
      resolved = next;
      continue;
    }
    if (++links > 40) return join(next, ...queue);
    const target = readlinkSync(next);
    if (target.startsWith("/")) resolved = "/";
    queue.unshift(...target.split("/"));
  }
  return resolved;
}

function isRelativeTo(target, root) {
  return target === root || target.startsWith(root === "/" ? "/" : `${root}/`);
}

function isFile(target) {
  try {
    return statSync(target).isFile();
  } catch {
    return false;
  }
}

function isDir(target) {
  try {
    return statSync(target).isDirectory();
  } catch {
    return false;
  }
}

function isSymlink(target) {
  try {
    return lstatSync(target).isSymbolicLink();
  } catch {
    return false;
  }
}

function isExecutable(target) {
  try {
    accessSync(target, constants.X_OK);
  } catch {
    return false;
  }
  return isFile(target);
}

// Like shutil.which: search the process PATH for an executable file.
function which(name) {
  const search = process.env.PATH ?? "/usr/bin:/bin";
  if (!search) return null;
  for (const dir of search.split(":")) {
    const candidate = path.join(dir || ".", name);
    if (isExecutable(candidate)) return dir ? `${dir}/${name}` : name;
  }
  return null;
}

function removePrefix(text, prefix) {
  return text.startsWith(prefix) ? text.slice(prefix.length) : text;
}

function removeSuffix(text, suffix) {
  return suffix && text.endsWith(suffix) ? text.slice(0, -suffix.length) : text;
}

/** GitHub checkout spelling, independent of transport and pinned ref. */
function githubPath(source) {
  source = removePrefix(source, "git:");
  const match = /^(?:https?:\/\/github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:|github\.com\/)([^/\s]+)\/([^/@\s]+)(?:@[^\s]+)?\/?$/.exec(source);
  if (match) return [match[1], removeSuffix(match[2], ".git")];
  return null;
}

/** Case-insensitive identity is separate from native checkout spelling. */
function github(source) {
  const parts = githubPath(source);
  return parts ? parts.map((part) => part.toLowerCase()) : null;
}

const sameIdentity = (a, b) => a !== null && b !== null && isDeepStrictEqual(a, b);
const identityKey = (identity) => JSON.stringify(identity);

function sourceOf(entry) {
  return typeof entry === "string" ? entry : entry.source;
}

function validateSettings(data) {
  if (!isObject(data)) throw new ProvisionError("Pi settings must be a JSON object");
  for (const key of ["extensions", "skills", "prompts", "themes", "defaultTools"]) {
    if (hasOwn(data, key) && !isStringList(data[key])) {
      throw new ProvisionError(`Invalid Pi settings field: ${key}`);
    }
  }
  const packages = hasOwn(data, "packages") ? data.packages : [];
  if (!Array.isArray(packages)) throw new ProvisionError("Invalid Pi packages list");
  for (const entry of packages) {
    if (typeof entry === "string" && entry) continue;
    if (!isObject(entry) || typeof entry.source !== "string" || !entry.source) {
      throw new ProvisionError("Invalid Pi package entry");
    }
    for (const key of ["extensions", "skills", "prompts", "themes"]) {
      if (hasOwn(entry, key) && !isStringList(entry[key])) {
        throw new ProvisionError("Invalid Pi package resource filter");
      }
    }
  }
}

const packagesOf = (data) => (hasOwn(data, "packages") ? data.packages : []);

function need(object, key) {
  if (!hasOwn(object, key)) throw new Error(`missing baseline key: ${key}`);
  return object[key];
}

// Same output as Python's json.dump(indent=2): ASCII-only, two-space indent.
function dumpJson(data) {
  const text = JSON.stringify(data, null, 2);
  return text.replace(/[\u007f-\uffff]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`);
}

function readText(file) {
  // Fatal decoding without BOM stripping, so invalid UTF-8 or a BOM is rejected.
  return new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(readFileSync(file));
}

class Provisioner {
  constructor() {
    const rawHome = process.env.HOME ?? "";
    if (!rawHome.startsWith("/") || resolvePath(join(rawHome)) === "/") {
      throw new ProvisionError("HOME must be absolute and non-root");
    }
    this.home = join(rawHome);
    if (!isDir(this.home) || rawHome.split("/").slice(1).some((p) => p === "." || p === "..")) {
      throw new ProvisionError("Unsafe HOME");
    }
    this.root = resolvePath(this.home);
    this.agent = join(this.home, ".pi/agent");
    this.settings = join(this.agent, "settings.json");
    this.cache = join(this.home, ".cache/pi-herdsman-build");
    this.backups = join(this.home, ".local/state/dotfiles/backups");
    this.env = { ...process.env, PI_CODING_AGENT_DIR: this.agent };
    this.origins = new Map();
    // Validate every managed state root before any native command or write.
    for (const target of [
      this.settings, join(this.agent, "git"), join(this.agent, "npm"),
      this.cache, join(this.cache, "package.json"),
      join(this.cache, "package-lock.json"), join(this.cache, "node_modules/esbuild"),
      join(this.cache, "node_modules/esbuild/package.json"),
      this.backups, join(this.home, ".local/bin"), join(this.agent, "bin"),
    ]) {
      this.safe(target);
    }
    this.safe(join(this.agent, "git/.gitignore"));
    this.npmState(join(this.agent, "npm"));
    this.npmState(this.cache);
    this.read();
  }

  npmState(root) {
    // npm writes these independently of the selected package directory.
    // Apply to Pi's shared prefix, Git dependency installs and our build cache.
    for (const child of [".gitignore", "package.json", "package-lock.json", "npm-shrinkwrap.json",
      "node_modules", "node_modules/.package-lock.json", "node_modules/.bin"]) {
      this.safe(join(root, child));
    }
  }

  safe(target) {
    if (!target.startsWith("/") || !isRelativeTo(resolvePath(target), this.root)) {
      throw new ProvisionError("Refusing managed path outside HOME");
    }
    if (target === this.settings && isSymlink(target)) {
      throw new ProvisionError("Refusing symlinked Pi settings.json");
    }
    return target;
  }

  read() {
    this.safe(this.settings);
    let data;
    try {
      data = existsSync(this.settings) ? JSON.parse(readText(this.settings)) : {};
    } catch {
      throw new ProvisionError("Could not read valid Pi settings.json");
    }
    validateSettings(data);
    return data;
  }

  backup() {
    this.safe(this.backups);
    this.safe(this.settings);
    if (existsSync(this.settings)) {
      mkdirSync(this.backups, { recursive: true });
      const backupDir = mkdtempSync(join(this.backups, "pi-settings."));
      const backup = join(backupDir, "settings.json");
      // The private directory and file never expose machine-local settings.
      const fd = openSync(backup, "wx", 0o600);
      try {
        writeSync(fd, readFileSync(this.settings));
      } finally {
        closeSync(fd);
      }
    }
  }

  write(data) {
    const current = this.read();
    if (isDeepStrictEqual(current, data)) return;
    this.backup();
    mkdirSync(this.agent, { recursive: true });
    let name;
    let fd;
    for (;;) {
      name = join(this.agent, `.settings.${randomBytes(6).toString("base64url").replace(/[^A-Za-z0-9]/g, "x")}`);
      try {
        fd = openSync(name, "wx", 0o600);
        break;
      } catch (error) {
        if (error.code !== "EEXIST") throw error;
      }
    }
    try {
      try {
        writeSync(fd, `${dumpJson(data)}\n`);
        fsyncSync(fd);
      } finally {
        closeSync(fd);
      }
      this.safe(this.settings);
      renameSync(name, this.settings);
    } finally {
      if (existsSync(name)) unlinkSync(name);
    }
  }

  command(args, cwd) {
    // CLI output can include settings or credentials; report only our own status.
    const result = spawnSync(args[0], args.slice(1), {
      cwd: cwd ?? this.home, env: this.env, stdio: ["inherit", "ignore", "ignore"],
    });
    if (result.error) throw new ProvisionError(`Could not execute ${path.basename(args[0])}`);
    if (result.status !== 0) {
      if (args.length > 2 && args[1] === "install" && github(args[2])) {
        throw new ProvisionError(
          "Pi Git package installation failed. If the repository is private, " +
          "run gh auth login and gh auth setup-git on this machine; " +
          "then rerun sh scripts/pi.sh. No credentials are copied by setup.",
        );
      }
      throw new ProvisionError(`${path.basename(args[0])} failed; rerun sh scripts/pi.sh after resolving the failure`);
    }
  }

  localPath(source) {
    if (source.startsWith("~/")) return join(this.home, source.slice(2));
    if (source.startsWith("/")) return join(source);
    if (source.startsWith("./") || source.startsWith("../")) return join(this.agent, source);
    return null;
  }

  identity(source) {
    const pub = github(source);
    if (pub) return ["github", ...pub];
    const local = this.localPath(source);
    if (local !== null) {
      if (!this.origins.has(local)) {
        // Read-only origin inspection identifies legacy local Herdsman clones.
        const result = spawnSync("git", ["-C", local, "config", "--get", "remote.origin.url"], {
          cwd: this.home, env: this.env, encoding: "utf8", stdio: ["inherit", "pipe", "pipe"],
        });
        if (result.error) throw result.error;
        this.origins.set(local, result.status === 0 ? github(result.stdout.trim()) : null);
      }
      if (sameIdentity(this.origins.get(local), ["boadij", "pi-herdsman"])) {
        return ["github", "boadij", "pi-herdsman"];
      }
      return ["local", resolvePath(local)];
    }
    if (source.startsWith("npm:")) {
      let name = source.slice(4);
      if (name.slice(1).includes("@")) name = name.slice(0, name.lastIndexOf("@"));
      return ["npm", name];
    }
    return ["other", source];
  }

  artifact(source) {
    const local = this.localPath(source);
    if (local !== null) return local;
    const identity = this.identity(source);
    if (identity[0] === "github") {
      const [owner, repo] = githubPath(source);
      return join(this.agent, "git/github.com", owner, repo);
    }
    if (identity[0] === "npm") return join(this.agent, "npm/node_modules", identity[1]);
    throw new ProvisionError("Unsupported baseline package source");
  }

  updateMarker(source, target) {
    if (this.localPath(source) === null && github(source)) {
      return this.safe(join(path.dirname(target), `.${path.basename(target)}.pi-update-incomplete`));
    }
    return null;
  }

  artifactsReady(source, target) {
    const marker = this.updateMarker(source, target);
    return isFile(join(target, "package.json")) &&
      !(marker !== null && (existsSync(marker) || isSymlink(marker)));
  }

  buildHerdsman(checkout) {
    this.safe(checkout);
    const definitions = ["generalist", "implementer", "researcher", "reviewer", "scout"];
    const outputs = [join(checkout, "dist/index.js"),
      ...definitions.map((name) => join(checkout, `dist/agent-definitions/${name}.md`))];
    for (const target of [join(checkout, "dist"), join(checkout, "node_modules/esbuild"), ...outputs]) {
      this.safe(target);
    }
    if (outputs.every(isFile)) return;
    const buildScript = this.safe(join(checkout, "scripts/build.mjs"));
    if (!isFile(buildScript)) throw new ProvisionError("Herdsman upstream build script is missing");
    const esbuild = join(checkout, "node_modules/esbuild");
    const cacheEsbuild = this.safe(join(this.cache, "node_modules/esbuild"));
    const ownedLink = isSymlink(esbuild) && readlinkSync(esbuild) === cacheEsbuild;
    const missingEntry = !existsSync(esbuild) && !isSymlink(esbuild);
    if (missingEntry || ownedLink) {
      // Cache eviction can leave our absolute symlink dangling. Recreate
      // its dependency without replacing this link or foreign dependencies.
      this.safe(join(cacheEsbuild, "package.json"));
      this.npmState(this.cache);
      if (!isFile(join(cacheEsbuild, "package.json"))) {
        this.command(["npm", "install", "--prefix", this.cache, "--no-audit",
          "--no-fund", "esbuild@0.28.2"]);
      }
      if (missingEntry) {
        mkdirSync(path.dirname(esbuild), { recursive: true });
        symlinkSync(cacheEsbuild, esbuild, "dir");
      }
    }
    this.command(["node", buildScript], checkout);
    if (!outputs.every(isFile)) throw new ProvisionError("Herdsman build outputs are incomplete");
  }

  run(baseline) {
    validateSettings(baseline);
    let data = this.read();
    const prefix = join(this.home, ".local");
    const qmd = which("qmd") ?? (isExecutable(join(prefix, "bin/qmd")) ? join(prefix, "bin/qmd") : null);
    if (!qmd) {
      // Preflight QMD even before Pi installation when both CLIs are missing.
      this.safe(prefix);
      this.npmState(prefix);
      this.safe(join(prefix, "bin/qmd"));
      this.safe(join(prefix, "lib/node_modules"));
      const target = this.safe(join(prefix, "lib/node_modules/@tobilu/qmd"));
      this.npmState(target);
    }
    // Resolve and validate all baseline destinations, including a local clone,
    // before the first install or settings write.
    const existing = new Map();
    for (const entry of packagesOf(data)) existing.set(identityKey(this.identity(sourceOf(entry))), entry);
    const plan = [];
    for (const entry of need(baseline, "packages")) {
      const identity = this.identity(sourceOf(entry));
      const selected = existing.has(identityKey(identity)) ? existing.get(identityKey(identity)) : entry;
      const target = this.artifact(sourceOf(selected));
      this.safe(target);
      this.safe(join(target, "package.json"));
      this.updateMarker(sourceOf(selected), target);
      if (identity[0] === "github" && this.localPath(sourceOf(selected)) === null) {
        this.npmState(target);
        this.safe(join(target, ".git"));
      }
      if (sameIdentity(identity, ["github", "boadij", "pi-herdsman"])) {
        for (const child of ["dist", "dist/index.js", "node_modules/esbuild", "scripts/build.mjs",
          "dist/agent-definitions/generalist.md",
          "dist/agent-definitions/implementer.md",
          "dist/agent-definitions/researcher.md",
          "dist/agent-definitions/reviewer.md",
          "dist/agent-definitions/scout.md"]) {
          this.safe(join(target, child));
        }
      }
      plan.push([identity, entry]);
    }
    let pi = which("pi");
    if (!pi) {
      for (const candidate of [join(this.home, ".local/bin/pi"), join(this.agent, "bin/pi")]) {
        if (isExecutable(candidate)) {
          pi = candidate;
          break;
        }
      }
    }
    if (!pi) {
      console.log("Pi not found; installing Pi with npm...");
      const prefix = this.safe(join(this.home, ".local"));
      this.npmState(prefix);
      this.safe(join(prefix, "bin/pi"));
      this.safe(join(prefix, "lib/node_modules"));
      this.safe(join(prefix, "lib/node_modules/@earendil-works/pi-coding-agent"));
      this.command(["npm", "install", "--global", "--prefix", prefix,
        "--ignore-scripts", "--no-audit", "--no-fund", "@earendil-works/pi-coding-agent"]);
      pi = join(prefix, "bin/pi");
      if (!isExecutable(pi)) throw new ProvisionError("Pi installation did not create an executable");
    }
    if (!qmd) {
      console.log("QMD not found; installing QMD with npm...");
      // QMD's native dependencies require normal npm lifecycle scripts.
      this.command(["npm", "install", "--global", "--prefix", prefix,
        "--no-audit", "--no-fund", "@tobilu/qmd"]);
      if (!isExecutable(join(prefix, "bin/qmd"))) {
        throw new ProvisionError("QMD installation did not create an executable");
      }
    }
    for (const key of ["extensions", "skills", "defaultTools"]) {
      if (!hasOwn(data, key)) data[key] = need(baseline, key);
    }
    this.write(data);
    for (const [identity, entry] of plan) {
      data = this.read();
      const matches = packagesOf(data).filter((e) => sameIdentity(this.identity(sourceOf(e)), identity));
      const selected = matches.length ? matches[0] : entry;
      const target = this.artifact(sourceOf(selected));
      this.safe(target);
      this.safe(join(target, "package.json"));
      if (!matches.length || !this.artifactsReady(sourceOf(selected), target)) {
        console.log("Provisioning Pi package...");
        // Pi owns its settings update too; preserve the pre-installer
        // bytes even when our defaults and final merge are no-ops.
        this.npmState(join(this.agent, "npm"));
        if (identity[0] === "github" && this.localPath(sourceOf(selected)) === null) {
          this.npmState(target);
        }
        this.backup();
        try {
          this.command([pi, "install", sourceOf(selected), "--no-approve"]);
        } catch (error) {
          if (!(error instanceof ProvisionError)) throw error;
          if (!matches.length) {
            // Some CLI failures register the source before installation.
            // Remove only that new declaration, so retry retains baseline filters.
            const latest = this.read();
            latest.packages = packagesOf(latest)
              .filter((e) => !sameIdentity(this.identity(sourceOf(e)), identity));
            this.write(latest);
          }
          throw error;
        }
        const latest = this.read();
        if (!hasOwn(latest, "packages")) latest.packages = [];
        const packages = latest.packages;
        const others = () => packages.filter((e) => !sameIdentity(this.identity(sourceOf(e)), identity));
        if (!matches.length) {
          packages.splice(0, packages.length, ...others(), entry);
        } else {
          // Pi may normalize the source during repair. Keep the original
          // machine-local source/ref and filters exactly as configured.
          packages.splice(0, packages.length, ...others());
          const original = packagesOf(data);
          original.forEach((old, index) => {
            if (sameIdentity(this.identity(sourceOf(old)), identity)) {
              packages.splice(Math.min(index, packages.length), 0, old);
            }
          });
        }
        this.write(latest);
        this.safe(join(target, "package.json"));
        if (!this.artifactsReady(sourceOf(selected), target)) {
          throw new ProvisionError("Pi package artifacts are still missing after install");
        }
      }
      if (sameIdentity(identity, ["github", "boadij", "pi-herdsman"])) this.buildHerdsman(target);
    }
    const herdr = which("herdr");
    if (herdr) {
      this.command([herdr, "integration", "install", "pi"]);
    } else {
      console.log("Pi packages ready. Install herdr, then run: herdr integration install pi");
    }
    console.log("Pi package provisioning complete");
  }
}

function main() {
  try {
    const provisioner = new Provisioner();
    const baseline = JSON.parse(readText(process.argv[2]));
    provisioner.run(baseline);
  } catch (error) {
    // Do not include JSON decoding details or subprocess output (possibly secret).
    const message = error instanceof ProvisionError ? error.message : "Pi provisioning could not complete";
    console.error(`pi setup: ${message}`);
    return 1;
  }
  return 0;
}

process.exitCode = main();
