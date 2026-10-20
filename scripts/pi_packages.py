#!/usr/bin/env python3
"""Provision personal Pi packages without replacing machine-local configuration."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


class ProvisionError(Exception):
    pass


def github_path(source):
    """GitHub checkout spelling, independent of transport and pinned ref."""
    source = source.removeprefix("git:")
    match = re.fullmatch(
        r"(?:https?://github\.com/|ssh://git@github\.com/|git@github\.com:|github\.com/)"
        r"([^/\s]+)/([^/@\s]+)(?:@[^\s]+)?/?", source
    )
    if match:
        return (match[1], match[2].removesuffix(".git"))
    return None


def github(source):
    """Case-insensitive identity is separate from native checkout spelling."""
    path = github_path(source)
    return tuple(part.lower() for part in path) if path else None


def source_of(entry):
    return entry if isinstance(entry, str) else entry["source"]


def validate_settings(data):
    if not isinstance(data, dict):
        raise ProvisionError("Pi settings must be a JSON object")
    for key in ("extensions", "skills", "prompts", "themes", "defaultTools"):
        if key in data and (not isinstance(data[key], list) or
                            not all(isinstance(x, str) for x in data[key])):
            raise ProvisionError(f"Invalid Pi settings field: {key}")
    if not isinstance(data.get("packages", []), list):
        raise ProvisionError("Invalid Pi packages list")
    for entry in data.get("packages", []):
        if isinstance(entry, str) and entry:
            continue
        if not isinstance(entry, dict) or not isinstance(entry.get("source"), str) or not entry["source"]:
            raise ProvisionError("Invalid Pi package entry")
        for key in ("extensions", "skills", "prompts", "themes"):
            if key in entry and (not isinstance(entry[key], list) or
                                 not all(isinstance(x, str) for x in entry[key])):
                raise ProvisionError("Invalid Pi package resource filter")


class Provisioner:
    def __init__(self):
        raw_home = os.environ.get("HOME", "")
        if not raw_home.startswith("/") or Path(raw_home).resolve() == Path("/"):
            raise ProvisionError("HOME must be absolute and non-root")
        self.home = Path(raw_home)
        if not self.home.is_dir() or any(p in (".", "..") for p in raw_home.split("/")[1:]):
            raise ProvisionError("Unsafe HOME")
        self.root = self.home.resolve()
        self.agent = self.home / ".pi/agent"
        self.settings = self.agent / "settings.json"
        self.cache = self.home / ".cache/pi-herdsman-build"
        self.backups = self.home / ".local/state/dotfiles/backups"
        self.env = {**os.environ, "PI_CODING_AGENT_DIR": str(self.agent)}
        self.origins = {}
        # Validate every managed state root before any native command or write.
        for target in (self.settings, self.agent / "git", self.agent / "npm",
                       self.cache, self.cache / "package.json",
                       self.cache / "package-lock.json", self.cache / "node_modules/esbuild",
                       self.cache / "node_modules/esbuild/package.json",
                       self.backups, self.home / ".local/bin", self.agent / "bin"):
            self.safe(target)
        self.safe(self.agent / "git/.gitignore")
        self.npm_state(self.agent / "npm")
        self.npm_state(self.cache)
        self.read()

    def npm_state(self, root):
        # npm writes these independently of the selected package directory.
        # Apply to Pi's shared prefix, Git dependency installs and our build cache.
        for child in (".gitignore", "package.json", "package-lock.json", "npm-shrinkwrap.json",
                      "node_modules", "node_modules/.package-lock.json", "node_modules/.bin"):
            self.safe(root / child)

    def safe(self, target):
        target = Path(target)
        if not target.is_absolute() or not target.resolve().is_relative_to(self.root):
            raise ProvisionError("Refusing managed path outside HOME")
        if target == self.settings and target.is_symlink():
            raise ProvisionError("Refusing symlinked Pi settings.json")
        return target

    def read(self):
        self.safe(self.settings)
        try:
            data = json.loads(self.settings.read_text()) if self.settings.exists() else {}
        except (ValueError, OSError):
            raise ProvisionError("Could not read valid Pi settings.json") from None
        validate_settings(data)
        return data

    def backup(self):
        self.safe(self.backups)
        self.safe(self.settings)
        if self.settings.exists():
            self.backups.mkdir(parents=True, exist_ok=True)
            backup_dir = Path(tempfile.mkdtemp(prefix="pi-settings.", dir=self.backups))
            backup = backup_dir / "settings.json"
            # The private directory and file never expose machine-local settings.
            fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as stream:
                stream.write(self.settings.read_bytes())

    def write(self, data):
        current = self.read()
        if current == data:
            return
        self.backup()
        self.agent.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(prefix=".settings.", dir=self.agent)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(data, stream, indent=2)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            self.safe(self.settings)
            os.replace(name, self.settings)
        finally:
            if os.path.exists(name):
                os.unlink(name)

    def command(self, args, cwd=None):
        # CLI output can include settings or credentials; report only our own status.
        try:
            result = subprocess.run(args, cwd=cwd or self.home, env=self.env,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            raise ProvisionError(f"Could not execute {Path(args[0]).name}") from None
        if result.returncode:
            if len(args) > 2 and args[1] == "install" and github(args[2]):
                raise ProvisionError(
                    "Pi Git package installation failed. If the repository is private, "
                    "run gh auth login and gh auth setup-git on this machine; "
                    "then rerun sh scripts/pi.sh. No credentials are copied by setup."
                )
            raise ProvisionError(f"{Path(args[0]).name} failed; rerun sh scripts/pi.sh after resolving the failure")

    def local_path(self, source):
        if source.startswith("~/"):
            return self.home / source[2:]
        if source.startswith("/"):
            return Path(source)
        if source.startswith(("./", "../")):
            return self.agent / source
        return None

    def identity(self, source):
        public = github(source)
        if public:
            return ("github", *public)
        local = self.local_path(source)
        if local is not None:
            if str(local) not in self.origins:
                # Read-only origin inspection identifies legacy local Herdsman clones.
                result = subprocess.run(["git", "-C", str(local), "config", "--get", "remote.origin.url"],
                                        cwd=self.home, env=self.env, capture_output=True, text=True)
                origin = github(result.stdout.strip()) if result.returncode == 0 else None
                self.origins[str(local)] = origin
            if self.origins[str(local)] == ("boadij", "pi-herdsman"):
                return ("github", "boadij", "pi-herdsman")
            return ("local", str(local.resolve()))
        if source.startswith("npm:"):
            name = source[4:]
            name = name.rsplit("@", 1)[0] if "@" in name[1:] else name
            return ("npm", name)
        return ("other", source)

    def artifact(self, source):
        local = self.local_path(source)
        if local is not None:
            return local
        identity = self.identity(source)
        if identity[0] == "github":
            owner, repo = github_path(source)
            return self.agent / "git/github.com" / owner / repo
        if identity[0] == "npm":
            return self.agent / "npm/node_modules" / identity[1]
        raise ProvisionError("Unsupported baseline package source")

    def update_marker(self, source, target):
        if self.local_path(source) is None and github(source):
            return self.safe(target.parent / f".{target.name}.pi-update-incomplete")
        return None

    def artifacts_ready(self, source, target):
        marker = self.update_marker(source, target)
        return ((target / "package.json").is_file() and
                not (marker is not None and (marker.exists() or marker.is_symlink())))

    def build_herdsman(self, checkout):
        self.safe(checkout)
        definitions = ("generalist", "implementer", "researcher", "reviewer", "scout")
        outputs = [checkout / "dist/index.js"] + [
            checkout / f"dist/agent-definitions/{name}.md" for name in definitions]
        for target in [checkout / "dist", checkout / "node_modules/esbuild", *outputs]:
            self.safe(target)
        if all(p.is_file() for p in outputs):
            return
        build_script = self.safe(checkout / "scripts/build.mjs")
        if not build_script.is_file():
            raise ProvisionError("Herdsman upstream build script is missing")
        esbuild = checkout / "node_modules/esbuild"
        cache_esbuild = self.safe(self.cache / "node_modules/esbuild")
        owned_link = esbuild.is_symlink() and os.readlink(esbuild) == str(cache_esbuild)
        missing_entry = not esbuild.exists() and not esbuild.is_symlink()
        if missing_entry or owned_link:
            # Cache eviction can leave our absolute symlink dangling. Recreate
            # its dependency without replacing this link or foreign dependencies.
            self.safe(cache_esbuild / "package.json")
            self.npm_state(self.cache)
            if not (cache_esbuild / "package.json").is_file():
                self.command(["npm", "install", "--prefix", str(self.cache), "--no-audit",
                              "--no-fund", "esbuild@0.28.2"])
            if missing_entry:
                esbuild.parent.mkdir(parents=True, exist_ok=True)
                esbuild.symlink_to(cache_esbuild, target_is_directory=True)
        self.command(["node", str(build_script)], cwd=checkout)
        if not all(p.is_file() for p in outputs):
            raise ProvisionError("Herdsman build outputs are incomplete")

    def run(self, baseline):
        validate_settings(baseline)
        data = self.read()
        # Resolve and validate all baseline destinations, including a local clone,
        # before the first install or settings write.
        existing = {self.identity(source_of(e)): e for e in data.get("packages", [])}
        plan = []
        for entry in baseline["packages"]:
            identity = self.identity(source_of(entry))
            selected = existing.get(identity, entry)
            target = self.artifact(source_of(selected))
            self.safe(target)
            self.safe(target / "package.json")
            self.update_marker(source_of(selected), target)
            if identity[0] == "github" and self.local_path(source_of(selected)) is None:
                self.npm_state(target)
                self.safe(target / ".git")
            if identity == ("github", "boadij", "pi-herdsman"):
                for child in ("dist", "dist/index.js", "node_modules/esbuild", "scripts/build.mjs",
                              "dist/agent-definitions/generalist.md",
                              "dist/agent-definitions/implementer.md",
                              "dist/agent-definitions/researcher.md",
                              "dist/agent-definitions/reviewer.md",
                              "dist/agent-definitions/scout.md"):
                    self.safe(target / child)
            plan.append((identity, entry, target))
        pi = shutil.which("pi")
        if not pi:
            for candidate in (self.home / ".local/bin/pi", self.agent / "bin/pi"):
                if candidate.is_file() and os.access(candidate, os.X_OK):
                    pi = str(candidate)
                    break
        if not pi:
            print("Pi not found; install Pi, then rerun: sh scripts/pi.sh")
            return
        for key in ("extensions", "skills", "defaultTools"):
            if key not in data:
                data[key] = baseline[key]
        self.write(data)
        for identity, entry, target in plan:
            data = self.read()
            matches = [e for e in data.get("packages", []) if self.identity(source_of(e)) == identity]
            selected = matches[0] if matches else entry
            target = self.artifact(source_of(selected))
            self.safe(target)
            self.safe(target / "package.json")
            if not matches or not self.artifacts_ready(source_of(selected), target):
                print("Provisioning Pi package...")
                # Pi owns its settings update too; preserve the pre-installer
                # bytes even when our defaults and final merge are no-ops.
                self.npm_state(self.agent / "npm")
                if identity[0] == "github" and self.local_path(source_of(selected)) is None:
                    self.npm_state(target)
                self.backup()
                try:
                    self.command([pi, "install", source_of(selected), "--no-approve"])
                except ProvisionError:
                    if not matches:
                        # Some CLI failures register the source before installation.
                        # Remove only that new declaration, so retry retains baseline filters.
                        latest = self.read()
                        latest["packages"] = [e for e in latest.get("packages", [])
                                              if self.identity(source_of(e)) != identity]
                        self.write(latest)
                    raise
                latest = self.read()
                packages = latest.setdefault("packages", [])
                if not matches:
                    packages[:] = [e for e in packages if self.identity(source_of(e)) != identity]
                    packages.append(entry)
                else:
                    # Pi may normalize the source during repair. Keep the original
                    # machine-local source/ref and filters exactly as configured.
                    packages[:] = [e for e in packages if self.identity(source_of(e)) != identity]
                    original = data.get("packages", [])
                    for index, old in enumerate(original):
                        if self.identity(source_of(old)) == identity:
                            packages.insert(min(index, len(packages)), old)
                self.write(latest)
                self.safe(target / "package.json")
                if not self.artifacts_ready(source_of(selected), target):
                    raise ProvisionError("Pi package artifacts are still missing after install")
            if identity == ("github", "boadij", "pi-herdsman"):
                self.build_herdsman(target)
        herdr = shutil.which("herdr")
        if herdr:
            self.command([herdr, "integration", "install", "pi"])
        else:
            print("Pi packages ready. Install herdr, then run: herdr integration install pi")
        print("Pi package provisioning complete")


def main():
    try:
        provisioner = Provisioner()
        baseline = json.loads(Path(sys.argv[1]).read_text())
        provisioner.run(baseline)
    except (ProvisionError, OSError, ValueError, RuntimeError) as error:
        # Do not include JSON decoding details or subprocess output (possibly secret).
        message = str(error) if isinstance(error, ProvisionError) else "Pi provisioning could not complete"
        print(f"pi setup: {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
