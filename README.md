# Wund Expertin Plus

One-page website for Sibylle Bürgi-Lütscher — Dipl. Wundexpertin SAfW, Liestal.

[![License](https://img.shields.io/github/license/Team-MaRo/wundexpertinplus?label=License)](LICENSE.txt)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa)][code-of-conduct]
[![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/wundexpertinplus)][docker]
[![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/wundexpertinplus)][docker]
[![Codacy grade](https://img.shields.io/codacy/grade/a7d3a41ddccf4662880b35ae48f67454/master)](https://www.codacy.com/manual/D3strukt0r/wundexpertinplus)

[![CI](https://github.com/Team-MaRo/wundexpertinplus/actions/workflows/ci.yml/badge.svg)][gh-action]
[![Pages](https://github.com/Team-MaRo/wundexpertinplus/actions/workflows/deploy-gh-pages.yml/badge.svg)][gh-action]
[![Docker](https://github.com/Team-MaRo/wundexpertinplus/actions/workflows/docker.yml/badge.svg)][gh-action]

## Stack

- **React Router 7** (file-based routing, dual-mode SSR + SPA)
- **React 19** + **TypeScript 5.9**
- **Vite 8** + **Tailwind v4** + **Sass**
- **i18next** (German UI, all strings in `app/locales/de.yml`)
- **Google Maps JS API** (client-side, via `@googlemaps/js-api-loader`)
- **pnpm 12** + **Node 24**
- **Nix flakes** (devShell + reproducible OCI image, no Dockerfile)

## Two deploys, one source

| Mode | Output | Host |
|------|--------|------|
| `SSR=false pnpm build` | `build/client/` (static SPA) | GitHub Pages |
| `pnpm build` | `build/{client,server}/` (Node SSR) | Nix OCI container (port 3000) |

The fork is `react-router.config.ts`'s `ssr: process.env.SSR !== 'false'`. CI builds both; `deploy-gh-pages.yml` sets `SSR=false`.

## Getting started

```shell
pnpm install
cp .env.dist .env.local   # then fill in VITE_GOOGLE_MAPS_API_KEY
pnpm dev                  # http://localhost:5173
```

The Google Maps key is origin-restricted (whitelisted to the deployed domain), so it can ship in the client bundle — but we still source it from env to keep rotation out of source diffs. Without a key, the map area falls back to its stylised placeholder.

Three other dev paths:

1. **Devcontainer** — VS Code → "Reopen in Container" (`.devcontainer/devcontainer.json`).
2. **Compose** — `docker compose up dev` (uses `nixos/nix` image to realise the dev shell + run Vite).
3. **Vagrant VM** — `vagrant up` boots a Debian VM with Docker + Traefik + mkcert for `https://wundexpertinplus.test`.

## Building

```shell
pnpm build              # SSR build
SSR=false pnpm build    # SPA build
pnpm preview            # serve build/client locally (4173)
```

## OCI image

```shell
nix build .#dockerImage
docker load < result
docker run --rm -p 3000:3000 d3strukt0r/wundexpertinplus:latest
```

On Windows / macOS without a host Nix install, run the `nix build` step inside `nixos/nix:2.34.6`.

## Contributing

Please read [CONTRIBUTING.md][contributing] for details on our code of conduct and the process for submitting pull requests.

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

## Versioning

We use [SemVer](http://semver.org/) for versioning. For available versions, see the [tags on this repository][gh-tags].

## Authors

### Special thanks for all the people who had helped this project so far

- **Manuele** - [D3strukt0r](https://github.com/D3strukt0r)

See also the full list of [contributors][gh-contributors] who participated in this project.

### I would like to join this list. How can I help the project?

We're currently looking for contributions for the following:

- [ ] Bug fixes
- [ ] Translations
- [ ] etc...

For more information, please refer to our [CONTRIBUTING.md][contributing] guide.

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## Acknowledgments

This project currently uses no third-party libraries or copied code.

[docker]: https://hub.docker.com/repository/docker/d3strukt0r/wundexpertinplus
[gh-action]: https://github.com/Team-MaRo/wundexpertinplus/actions
[gh-tags]: https://github.com/Team-MaRo/wundexpertinplus/tags
[gh-contributors]: https://github.com/Team-MaRo/wundexpertinplus/contributors
[contributing]: https://github.com/Team-MaRo/.github/blob/master/CONTRIBUTING.md
[code-of-conduct]: https://github.com/Team-MaRo/.github/blob/master/CODE_OF_CONDUCT.md
