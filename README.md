# Homebridge Advantage Air

Standalone Homebridge integration for Advantage Air systems.

## Development status

This branch contains the foundation for the v4 standalone rewrite.
It does not yet connect to controllers or create working accessories.

The existing v3 plugin remains on the `master` branch.
See [the v3 documentation](README-v3.md) for the existing Cmd4 integration.

## Requirements

- Node.js 22.10+ within v22, or Node.js v24
- Homebridge v1.8+ within v1, or v2

Compatibility testing is ongoing.

## Development

Install dependencies:

    npm ci

Check code style:

    npm run lint

Build:

    npm run build

The platform identifier is `AdvantageAir`.
The npm package name remains `homebridge-cmd4-advantageair`.

Publishing is disabled with `"private": true` while the foundation
is under development.

## Planned work

- Advantage Air API client
- Controller and zone discovery
- Shared polling and state caching
- Accessory control and cache restoration
- Explicit migration instructions for existing Cmd4 users

## Project history and attribution

This project continues the work of homebridge-cmd4-AdvantageAir.
Historical documentation, acknowledgements and credits are preserved
in README-v3.md and CHANGELOG.md.

The new foundation uses the official Homebridge plugin template:
https://github.com/homebridge/homebridge-plugin-template

The imported template commit is recorded in TEMPLATE_SOURCE.txt.
The original project licence is retained in LICENSE, and the template
licence is retained in LICENSE.homebridge-template.