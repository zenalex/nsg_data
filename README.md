# nsg_data

Data object model and data exchange with C# server for Flutter applications.

## Features

- **Data Object Model**: Complete data object model with support for various field types
- **Server Communication**: Built-in HTTP client for C# server communication
- **Local Database**: Hive-based local database for offline data storage
- **Authentication**: Phone-based authentication system with SMS verification
- **Password Validation**: Password strength checking and validation
- **Barcode Scanning**: Built-in barcode reader functionality
- **Table Management**: Advanced table data handling with CRUD operations
- **Reference Fields**: Support for typed and untyped reference fields
- **Image Handling**: Image upload and management capabilities
- **Localization**: Multi-language support with locale management
- **Error Handling**: Comprehensive error handling and user feedback

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  nsg_data: ^0.3.0-beta.1
```

## Usage

```dart
import 'package:nsg_data/nsg_data.dart';

// Initialize the data provider
final provider = NsgDataProvider();
await provider.initialize();

// Create a data item
final item = NsgDataItem();
item.setValue('name', 'John Doe');
item.setValue('age', 30);

// Save to server
await provider.postItem(item);
```

## Dependencies

This package depends on `nsg_controls` which should be published first due to circular dependency.

## Publishing Instructions

Due to circular dependency with `nsg_controls`, follow these steps:

1. First publish `nsg_controls` package
2. Update `nsg_data` to use hosted version of `nsg_controls`
3. Publish `nsg_data` package

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Aleksei Zenkov (zenkov25@gmail.com)
