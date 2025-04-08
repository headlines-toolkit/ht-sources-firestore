# ht_sources_firestore

Firestore implementation of the `HtSourcesClient` interface. Handles communication with Cloud Firestore to manage news source data.

This package is part of **the** Headlines Toolkit project.

## Features

*   Provides a concrete implementation of the `HtSourcesClient` abstract class using Cloud Firestore as the backend.
*   Manages CRUD (Create, Read, Update, Delete) operations for news sources.
*   Handles Firestore-specific exceptions and maps them to `ht_sources_client` defined exceptions (e.g., `SourceCreateFailure`, `SourceNotFoundException`).

## Getting started

This package is intended to be used internally within the Headlines Toolkit project and is not published on pub.dev.

If you need to use it directly, you can add it as a git dependency in your `pubspec.yaml`:

```yaml
dependencies:
  ht_sources_client:
    git:
      url: https://github.com/headlines-toolkit/ht-sources-client.git
  ht_sources_firestore:
    git:
      url: https://github.com/headlines-toolkit/ht-sources-firestore.git
      # Optional: specify a ref (branch, tag, commit)
      # ref: main
```

You also need to have `cloud_firestore` and `firebase_core` set up in your Flutter project. Follow the official Firebase setup guide for Flutter: [https://firebase.google.com/docs/flutter/setup](https://firebase.google.com/docs/flutter/setup)

## Usage

Import the package and the base client package:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_sources_client/ht_sources_client.dart' as client;
import 'package:ht_sources_firestore/ht_sources_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Required for initialization

Future<void> main() async {
  // Ensure Firebase is initialized (Add your Firebase options)
  // WidgetsFlutterBinding.ensureInitialized(); // If in Flutter app
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Get the Firestore instance
  final firestore = FirebaseFirestore.instance;

  // Create the client instance
  final sourcesClient = HtSourcesFirestore(firestore: firestore);

  // Example: Create a new source
  try {
    final newSource = client.Source(
      id: 'unique-source-id', // Usually generated or assigned
      name: 'Example News Site',
      url: 'https://example.com/news',
      description: 'A sample news source.',
      language: 'en',
      country: 'US',
    );
    final createdSource = await sourcesClient.createSource(source: newSource);
    print('Source created: ${createdSource.name}');

    // Example: Get a source
    final fetchedSource = await sourcesClient.getSource(id: 'unique-source-id');
    print('Source fetched: ${fetchedSource.name}');

    // Example: Get sources with pagination (first page, limit 5)
    final firstPageSources = await sourcesClient.getSources(limit: 5);
    print('Fetched ${firstPageSources.length} sources on the first page.');
    String? lastSourceId;
    if (firstPageSources.isNotEmpty) {
      lastSourceId = firstPageSources.last.id;
      print('Last source ID on first page: $lastSourceId');
    }

    // Example: Get the next page of sources (if available)
    if (lastSourceId != null) {
      final nextPageSources = await sourcesClient.getSources(
        limit: 5,
        startAfterId: lastSourceId,
      );
      print('Fetched ${nextPageSources.length} sources on the next page.');
    }

    // Example: Get all sources (without pagination)
    // Note: Be cautious with large datasets in production.
    // final allSources = await sourcesClient.getSources();
    // print('Fetched ${allSources.length} sources in total.');


    // Example: Update a source
    final updatedSourceData = fetchedSource.copyWith(
      description: 'An updated description for the sample news source.',
    );
    final updatedSource = await sourcesClient.updateSource(source: updatedSourceData);
    print('Source updated: ${updatedSource.description}');

    // Example: Delete a source
    await sourcesClient.deleteSource(id: 'unique-source-id');
    print('Source deleted.');

  } on client.SourceException catch (e) {
    print('An error occurred: $e');
  } catch (e) {
    print('An unexpected error occurred: $e');
  }
}

```

## License

This software is licensed under the [PolyForm Free Trial License 1.0.0](LICENSE). Please review the terms before use.
