# Contributing to Ciyue

Thank you for your interest in contributing to Ciyue!

## Developing

- Make your changes with clear, descriptive commit messages.
- Ensure your code passes all tests.

### Requirements

- An editor, such as [VS Code](https://code.visualstudio.com/)
- Flutter development environment. Follow [the official installation guide](https://docs.flutter.dev/get-started/install)

### Using justfile

We use [just](https://github.com/casey/just) as a command runner to simplify common development tasks.

If you don't have just installed, follow the [installation guide](https://github.com/casey/just#installation).

Common commands:

```bash
$ just build_runner      # Run code generation
$ just make-migrations   # Generate database migrations
$ just icon              # Generate app icons
```

### Build

```bash
$ flutter build android
$ flutter build windows
$ flutter build linux
```

### Running

```bash
$ flutter run
```

## Translations

We welcome contributions to help translate Ciyue into more languages!

[Translate Ciyue on Weblate](https://hosted.weblate.org/engage/ciyue/)

Weblate makes it easy to collaborate on translations online. Please do not edit `.arb` files directly.

## Reporting Issues

- Search existing issues before opening a new one.
- Provide detailed information to help us reproduce and fix the issue.

## Final

We appreciate your contributions!