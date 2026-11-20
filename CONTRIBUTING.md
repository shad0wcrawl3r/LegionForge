# Contributing

## Workflow

`main` is protected. Nothing is pushed to it directly.

1. Branch from an up-to-date `main`, named `<type>/<short-description>`
   (e.g. `feat/niri-session`, `fix/selinux-switch`).
2. Open a pull request. The PR title must follow
   [Conventional Commits](https://www.conventionalcommits.org): `type(scope): subject`.
3. Wait for the required checks: **Build and push image** and **Lint PR title**.
   Resolve all review conversations.
4. **Squash-merge.** The PR title becomes the single commit on `main` and the
   branch is deleted automatically.

Every merge to `main` triggers a signed image build at
`ghcr.io/shad0wcrawl3r/legionforge`, so treat merging as releasing.

## Commit / PR title types

| Type       | Use for                                                    |
|------------|------------------------------------------------------------|
| `feat`     | New packages, sessions, services or user-facing behaviour  |
| `fix`      | Fixes to the image or build                                |
| `perf`     | Smaller/faster image or boot                               |
| `refactor` | Restructuring build scripts without behaviour change       |
| `docs`     | README / docs only (does not trigger an image build)       |
| `ci`       | GitHub Actions, Dependabot, Renovate                       |
| `build`    | Containerfile, Justfile, disk/ISO config                   |
| `chore`    | Anything else                                              |
| `revert`   | Reverting a previous change                                |

Subjects are imperative, lowercase, no trailing period:
`feat: add niri and noctalia shell`. Append `!` for changes that need users
to act (e.g. `feat!: switch base to bazzite-deck-gnome`).

## Smoke test

Every build runs `.github/scripts/smoke-test.sh` before anything is pushed. It
checks:

- the expected packages are installed;
- Switch to Desktop opens niri, and Noctalia is set to start with it;
- no Noctalia settings are shipped, so the first-run wizard appears;
- every SELinux type in the image already exists in the policy of
  `DEVICE_BASE_IMAGE` (set in `build.yml`). That is the image the Legion Go
  switches or upgrades from. If the check fails, `bootc switch` would fail
  on the device with `fsetxattr(security.selinux): Invalid argument`.

If you change the base variant in `Containerfile`, check what the device runs
(`bootc status`) and update `DEVICE_BASE_IMAGE` to match.

## Signing key

Images are signed with cosign. `cosign.pub` is committed; the private key is the
`SIGNING_SECRET` repository secret and must never be committed (`cosign.key` is
gitignored).
