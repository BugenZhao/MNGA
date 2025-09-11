# MNGA Project Explained for Agents

## Project Structure

MNGA consists of two main components:

- **SwiftUI UI Module** - Handles user interface and interactions
- **Rust Business Module** - Handles core business logic, networking, and data processing

The two modules communicate via FFI using Protocol Buffers for data exchange.

## Development Workflow

### After updating Rust code

```bash
make logic-ios
```

Compiles a new logic framework for Swift to link against.

### After updating .proto files

```bash
make swift-pb
```

Generates Swift protobuf code. Rust protobuf code is generated automatically during compilation.

## Common Commands

- `make logic-ios` - Build iOS framework
- `make swift-pb` - Generate Swift protobuf code
- `make logic-sim` - Build simulator-only version (faster for development)
- `make logic-deploy` - Build production version

## Notes for Agents

- Avoid any Chinese in source code, including comments and string literals.
