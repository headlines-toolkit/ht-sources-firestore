//
// ignore_for_file: lines_longer_than_80_chars, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_sources_client/ht_sources_client.dart' as client;

/// {@template ht_sources_firestore}
/// A Firestore implementation of the [client.HtSourcesClient] interface.
///
/// Handles communication with Cloud Firestore to manage [client.Source] data,
/// including fetching sources with pagination support.
/// {@endtemplate}
class HtSourcesFirestore implements client.HtSourcesClient {
  /// {@macro ht_sources_firestore}
  ///
  /// Requires a [FirebaseFirestore] instance.
  HtSourcesFirestore({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// The Firestore collection reference for sources.
  /// Assumes a default sort order (e.g., by document ID or a specific field
  /// like 'name') suitable for cursor-based pagination.
  /// **Important:** For reliable pagination with `startAfterDocument`,
  /// the query *must* include an `orderBy` clause matching the field used
  /// in the `startAfterDocument` snapshot. Let's assume ordering by name for now.
  /// If a different order is needed, adjust the `orderBy` clause accordingly.
  late final Query<Map<String, dynamic>> _sourcesQuery =
      _firestore.collection('sources').orderBy('name'); // Example order

  // Helper to get the base collection reference when needed without ordering
  CollectionReference<Map<String, dynamic>> get _sourcesCollection =>
      _firestore.collection('sources');

  @override
  Future<client.Source> createSource({required client.Source source}) async {
    try {
      // Use the source's ID as the document ID for predictability.
      final docRef = _sourcesCollection.doc(source.id);
      // Ensure toJson includes the ID if the model expects it,
      // otherwise Firestore handles the ID separately.
      // Assuming Source.toJson() does NOT include the 'id' field itself.
      await docRef.set(source.toJson());
      // Return the original source object as confirmation.
      // Firestore doesn't return the created doc directly on set,
      // so we return the input which should now match the stored state.
      return source;
    } on FirebaseException catch (e, stackTrace) {
      // Log the specific Firestore error for debugging.
      print(
        'Firestore Error creating source: ${e.message} (${e.code})\n$stackTrace',
      );
      throw client.SourceCreateFailure(
        'Failed to create source in Firestore: ${e.message} (${e.code})',
      );
    } catch (e, stackTrace) {
      // Catch any other unexpected errors.
      print('Unexpected Error creating source: $e\n$stackTrace');
      throw client.SourceCreateFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> deleteSource({required String id}) async {
    try {
      final docRef = _sourcesCollection.doc(id);
      // Check existence first to throw the correct custom exception.
      // Use server source to ensure we check the actual persisted state.
      final snapshot =
          await docRef.get(const GetOptions(source: Source.server));

      if (!snapshot.exists) {
        throw const client.SourceNotFoundException();
      }

      await docRef.delete();
    } on FirebaseException catch (e, stackTrace) {
      // Log the specific Firestore error.
      print('Firestore Error deleting source: $e\n$stackTrace');
      throw client.SourceDeleteFailure(
        'Failed to delete source from Firestore: ${e.message} (${e.code})',
      );
    } on client.SourceNotFoundException {
      rethrow; // Re-throw specific exception if needed upstream.
    } catch (e, stackTrace) {
      // Catch any other unexpected errors.
      print('Unexpected Error deleting source: $e\n$stackTrace');
      throw client.SourceDeleteFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<client.Source> getSource({required String id}) async {
    try {
      final docRef = _sourcesCollection.doc(id);
      // Use server source to get the latest data.
      final snapshot =
          await docRef.get(const GetOptions(source: Source.server));

      if (!snapshot.exists) {
        throw const client.SourceNotFoundException();
      }
      final data = snapshot.data();
      if (data == null) {
        // This case is less likely if snapshot.exists is true, but good practice.
        throw client.SourceFetchFailure(
          'Firestore document data was unexpectedly null for id: $id',
        );
      }
      try {
        // Add the document ID to the JSON data before parsing,
        // as Firestore snapshots don't include it in data() by default.
        final jsonData = {...data, 'id': snapshot.id};
        return client.Source.fromJson(jsonData);
      } catch (e, stackTrace) {
        // Catch potential FormatException or other errors during parsing.
        print('Error parsing source data for id: $id. Error: $e\n$stackTrace');
        throw client.SourceFetchFailure(
          'Failed to parse source data for id: $id. Error: $e',
        );
      }
    } on FirebaseException catch (e, stackTrace) {
      // Log the specific Firestore error.
      print('Firestore Error getting source: $e\n$stackTrace');
      throw client.SourceFetchFailure(
        'Failed to get source from Firestore: ${e.message} (${e.code})',
      );
    } on client.SourceNotFoundException {
      rethrow; // Re-throw specific exception.
    } catch (e, stackTrace) {
      // Catch any other unexpected errors.
      print('Unexpected Error getting source: $e\n$stackTrace');
      // Avoid double-wrapping if it's already the correct failure type.
      if (e is client.SourceFetchFailure) {
        rethrow;
      }
      throw client.SourceFetchFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<List<client.Source>> getSources({
    int? limit,
    String? startAfterId,
  }) async {
    try {
      // Start with the base query (which includes ordering by 'name')
      var query = _sourcesQuery;

      // Apply limit if provided and valid
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      } else if (limit != null && limit <= 0) {
        // Handle invalid limit (optional: could throw an error or log)
        print(
          'Warning: Invalid limit ($limit) provided. Fetching without limit.',
        );
      }

      // Apply pagination cursor if startAfterId is provided
      if (startAfterId != null && startAfterId.isNotEmpty) {
        // Fetch the document snapshot for the startAfterId to use as a cursor
        // Use server source to ensure the cursor is based on persisted data.
        final startAfterDoc = await _sourcesCollection
            .doc(startAfterId)
            .get(const GetOptions(source: Source.server));
        if (startAfterDoc.exists) {
          // Use startAfterDocument for cursor-based pagination.
          // Requires the query to be ordered consistently.
          query = query.startAfterDocument(startAfterDoc);
        } else {
          // Handle case where the startAfterId document doesn't exist.
          // Log a warning and proceed without the cursor, effectively starting from the beginning
          // of the potentially limited result set. This prevents errors but might
          // return unexpected results if the client assumes the cursor was valid.
          print(
            'Warning: startAfterId document "$startAfterId" not found. Fetching potentially limited results from the beginning.',
          );
        }
      }

      // Execute the final query, ensuring fresh data from the server.
      final querySnapshot =
          await query.get(const GetOptions(source: Source.server));

      final sources = <client.Source>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        try {
          // Add the document ID to the JSON data before parsing.
          final jsonData = {...data, 'id': doc.id};
          sources.add(client.Source.fromJson(jsonData));
        } catch (e, stackTrace) {
          // Log or handle individual document parsing errors.
          // Rethrowing as a general failure ensures the caller knows the list might be incomplete/incorrect.
          print('Failed to parse source doc ${doc.id}: $e\n$stackTrace');
          throw client.SourceFetchFailure(
            'Failed to parse source data for doc id: ${doc.id}. Error: $e',
          );
        }
      }
      return sources;
    } on FirebaseException catch (e, stackTrace) {
      // Log the specific Firestore error.
      print('Firestore Error getting sources: $e\n$stackTrace');
      throw client.SourceFetchFailure(
        'Failed to get sources from Firestore: ${e.message} (${e.code})',
      );
    } catch (e, stackTrace) {
      // Catch any other unexpected errors, including parsing errors rethrown above.
      print('Unexpected Error getting sources: $e\n$stackTrace');
      // Ensure a SourceFetchFailure is thrown for consistency.
      if (e is client.SourceFetchFailure) {
        rethrow;
      }
      throw client.SourceFetchFailure('An unexpected error occurred: $e');
    }
  }

  @override
  Future<client.Source> updateSource({required client.Source source}) async {
    try {
      final docRef = _sourcesCollection.doc(source.id);
      // Check for existence first using server data to throw the correct exception.
      final snapshot =
          await docRef.get(const GetOptions(source: Source.server));
      if (!snapshot.exists) {
        throw const client.SourceNotFoundException();
      }

      // Use update for partial updates or set with merge:true if you prefer.
      // Using set (overwrite) here as per the original code's apparent intent.
      // Ensure toJson() provides the complete data for the update.
      await docRef.set(source.toJson());
      // Return the input source as confirmation, assuming the update was successful.
      return source;
    } on FirebaseException catch (e, stackTrace) {
      // Log the specific Firestore error.
      print('Firestore Error updating source: $e\n$stackTrace');
      throw client.SourceUpdateFailure(
        'Failed to update source in Firestore: ${e.message} (${e.code})',
      );
    } on client.SourceNotFoundException {
      rethrow; // Re-throw specific exception.
    } catch (e, stackTrace) {
      // Catch any other unexpected errors.
      print('Unexpected Error updating source: $e\n$stackTrace');
      throw client.SourceUpdateFailure('An unexpected error occurred: $e');
    }
  }
}
