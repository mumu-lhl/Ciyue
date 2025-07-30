# Flutter

Best practice for Flutter.

## Code Guidelines

* Use dependency injection (`provider`)
* Use immutable data models (`freezed`)
* Use the command pattern

### Programming

* Prefer `Result<T>` rather than `try...catch...`
* Prefer double quotes rather than single quotes
* Less comments

## Best Architecture

Follow:

* Flutter's Best Architecture Layer: UI Layer, Logic Layer, Data Layer
* Separation of concerns
* Single source of truth
* Unidirectional data flow
* UI is a function of (immutable) state
* Extensibility: Each piece of architecture should have a well defined list of inputs and outputs.
* Testability
* Views <-> View models <-> Repositories <-> Services

### Project Structure

* Views (UI Layer): at `lib/ui/`
* View models (UI Layer and Logic Layer): at `lib/viewModels/`
* Repositories (Data layer): at `lib/repositories/`
* Services (Data layer): at `lib/services/`

* Core: at `lib/core/`
* Database (Drift): at `lib/database/`
* UI Shared Widgets: at `lib/ui/core/`
* Data Model: at `lib/models/`

## Helper Commands

* `just build_runner` - Run build_runner
* `just make-migrations` - Make drift migrations
* `just icon` - Generate icons for different platforms

## Define Slash Commands

* `/cm` - Generate commit message by `git --no-pager diff`. It shouldn't just provide a simple description; instead, it should detail the specific features that were changed, the bugs that were fixed, and any refactoring that was applied.