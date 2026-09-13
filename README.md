# Homebridge Advantage Air

Standalone Homebridge integration for Advantage Air systems.

## Development status

This branch contains the v4 standalone rewrite in development.

It supports read-only controller polling and retains the last valid response
when a read fails. Each configured controller is read at startup, then
30 seconds after the previous attempt finishes.

It does not yet create working HomeKit accessories or send control commands.
Live hardware validation is still pending.

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

- Live controller validation
- Accessory discovery and control
- Accessory cache restoration and migration
- Independent validation of air conditioning, lighting and other device data
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