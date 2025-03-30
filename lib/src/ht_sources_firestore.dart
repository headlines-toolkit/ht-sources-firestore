import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_sources_client/ht_sources_client.dart' as client;

/// {@template ht_sources_firestore}
/// A Firestore implementation of the client.HtSourcesClient interface.
///
/// Handles communication with Cloud Firestore to manage [client.Source] data.
/// {@endtemplate}
class HtSourcesFirestore implements client.HtSourcesClient {
  /// {@macro ht_sources_firestore}
  ///
  /// Requires a [FirebaseFirestore] instance.
  HtSourcesFirestore({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// The Firestore collection reference for sources.
  late final CollectionReference<Map<String, dynamic>> _sourcesCollection =
      _firestore.collection('sources');

  @override
  Future<client.Source> createSource({required client.Source source}) async {
    try {
      await _sourcesCollection.doc(source.id).set(source.toJson());
      return source;
    } on FirebaseException catch (e) {
      // Log the error internally if needed
      // print('Firestore Error creating source: $e\n$stackTrace');
      // print('Firestore Error creating source: $e\n$stackTrace');
      throw client.SourceCreateFailure(
        'Failed to create source in Firestore: ${e.message} (${e.code})',
      );
    } catch (e) {
      // Catch any other unexpected errors
      // print('Unexpected Error creating source: $e\n$stackTrace');
      throw client.SourceCreateFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> deleteSource({required String id}) async {
    try {
      // Note: No change needed in the core logic here as we don't deserialize
      // on delete, but the type of docRef changes implicitly due to
      // _sourcesCollection change.
      final docRef = _sourcesCollection.doc(id);
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        throw const client.SourceNotFoundException();
      }

      await docRef.delete();
    } on FirebaseException catch (e) {
      // Log the error internally if needed
      // print('Firestore Error deleting source: $e\n$stackTrace');
      throw client.SourceDeleteFailure(
        'Failed to delete source from Firestore: ${e.message} (${e.code})',
      );
    } on client.SourceNotFoundException {
      rethrow; // Re-throw specific exception
    } catch (e) {
      // Catch any other unexpected errors
      // print('Unexpected Error deleting source: $e\n$stackTrace');
      throw client.SourceDeleteFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<client.Source> getSource({required String id}) async {
    try {
      final snapshot = await _sourcesCollection.doc(id).get();

      if (!snapshot.exists) {
        throw const client.SourceNotFoundException();
      }
      final data = snapshot.data();
      if (data == null) {
        // Handle cases where the document exists but data is null/empty
        throw client.SourceFetchFailure(
          'Firestore document data was null for id: $id',
        );
      }
      try {
        return client.Source.fromJson(data);
      } catch (e) {
        // Catch potential FormatException or other errors during parsing
        throw client.SourceFetchFailure(
          'Failed to parse source data for id: $id. Error: $e',
        );
      }
    } on FirebaseException catch (e) {
      // Log the error internally if needed
      // print('Firestore Error getting source: $e\n$stackTrace');
      // print('Firestore Error getting source: $e\n$stackTrace');
      throw client.SourceFetchFailure(
        'Failed to get source from Firestore: ${e.message} (${e.code})',
      );
    } on client.SourceNotFoundException {
      rethrow; // Re-throw specific exception
    } catch (e) {
      // Catch any other unexpected errors
      // print('Unexpected Error getting source: $e\n$stackTrace');
      throw client.SourceFetchFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<List<client.Source>> getSources() async {
    try {
      final querySnapshot = await _sourcesCollection.get();
      final sources = <client.Source>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Optionally, add more robust handling: skip invalid docs or throw
        try {
          sources.add(client.Source.fromJson(data));
        } catch (e) {
          // Log or handle individual document parsing errors if needed
          // print('Failed to parse source doc ${doc.id}: $e');
          // Depending on requirements, you might skip this doc or rethrow
          // For now, let's rethrow a general failure if any doc fails
          throw client.SourceFetchFailure(
            'Failed to parse source data for doc id: ${doc.id}. Error: $e',
          );
        }
      }
      return sources;
    } on FirebaseException catch (e) {
      // Log the error internally if needed
      // print('Firestore Error getting sources: $e\n$stackTrace');
      throw client.SourceFetchFailure(
        'Failed to get sources from Firestore: ${e.message} (${e.code})',
      );
    } catch (e) {
      // Catch any other unexpected errors
      // print('Unexpected Error getting sources: $e\n$stackTrace');
      throw client.SourceFetchFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<client.Source> updateSource({required client.Source source}) async {
    try {
      final docRef = _sourcesCollection.doc(source.id);
      // Check for existence first to throw the correct exception
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw const client.SourceNotFoundException();
      }

      // Manually convert to JSON before setting
      await docRef.set(source.toJson()); // Ensure toJson() is called
      return source;
    } on FirebaseException catch (e) {
      // Log the error internally if needed
      // print('Firestore Error updating source: $e\n$stackTrace');
      // print('Firestore Error updating source: $e\n$stackTrace');
      // print('Firestore Error updating source: $e\n$stackTrace');
      throw client.SourceUpdateFailure(
        'Failed to update source in Firestore: ${e.message} (${e.code})',
      );
    } on client.SourceNotFoundException {
      rethrow; // Re-throw specific exception
    } catch (e) {
      // Catch any other unexpected errors
      // print('Unexpected Error updating source: $e\n$stackTrace');
      throw client.SourceUpdateFailure('An unexpected error occurred: $e');
    }
  }
}
