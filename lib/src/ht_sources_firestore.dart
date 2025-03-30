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
  /// Uses a converter to automatically map between [client.Source] objects and
  /// Firestore documents.
  late final CollectionReference<client.Source> _sourcesCollection = _firestore
      .collection('sources')
      .withConverter<client.Source>(
        fromFirestore: (snapshot, _) {
          final data = snapshot.data();
          if (data == null) {
            // This should ideally not happen if snapshot.exists is true,
            // but handle defensively.
            throw FirebaseException(
              plugin: 'HtSourcesFirestore',
              code: 'null-data',
              message: 'Firestore snapshot data was null for id ${snapshot.id}',
            );
          }
          return client.Source.fromJson(data);
        },
        toFirestore: (source, _) => source.toJson(),
      );

  @override
  Future<client.Source> createSource({required client.Source source}) async {
    try {
      await _sourcesCollection.doc(source.id).set(source);
      return source;
    } on FirebaseException catch (e) {
      // Log the error internally if needed
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
      // The converter handles the data extraction and parsing
      final source = snapshot.data();
      if (source == null) {
        // This case should theoretically not happen if snapshot.exists is true
        // and the converter works, but handle defensively. It's already handled
        // inside the fromFirestore converter, but checking here adds safety.
        throw client.SourceFetchFailure(
          'Failed to parse source data for id: $id',
        );
      }
      return source;
    } on FirebaseException catch (e) {
      // Log the error internally if needed
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
      // The converter handles the data extraction and parsing for each doc
      return querySnapshot.docs.map((doc) => doc.data()).toList();
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

      // Use set with merge: true or update.
      // Set is often simpler with converters.
      await docRef.set(source); // Overwrites with the new source data
      return source;
    } on FirebaseException catch (e) {
      // Log the error internally if needed
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
