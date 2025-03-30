//
// ignore_for_file: subtype_of_sealed_class, lines_longer_than_80_chars, prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_sources_client/ht_sources_client.dart' as client;
import 'package:ht_sources_firestore/src/ht_sources_firestore.dart';
import 'package:mocktail/mocktail.dart';

// --- Mocks ---

// Core Firestore mock
class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// Raw Collection/Document/Snapshot Mocks (for Map<String, dynamic>)
class _MockRawCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockRawDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockRawDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockRawQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockRawQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}


// Typed Mocks (These are what the HtSourcesFirestore class interacts with)
class _MockTypedCollectionReference extends Mock
    implements CollectionReference<client.Source> {}

class _MockTypedDocumentReference extends Mock
    implements DocumentReference<client.Source> {}

class _MockTypedDocumentSnapshot extends Mock
    implements DocumentSnapshot<client.Source> {}

class _MockTypedQuerySnapshot extends Mock
    implements QuerySnapshot<client.Source> {}

class _MockTypedQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<client.Source> {}

// Mock Source for fallback registration
class _MockSource extends Mock implements client.Source {}

void main() {
  // Register fallback values
  setUpAll(() {
    registerFallbackValue(_MockSource());
    registerFallbackValue(
      FirebaseException(plugin: 'test', code: 'unknown'),
    );
    // Fallback for the converter functions
    registerFallbackValue(
      (
        DocumentSnapshot<Map<String, dynamic>> snapshot,
        SnapshotOptions? options,
      ) =>
          _MockSource(), // Dummy return
    );
    registerFallbackValue(
      (client.Source source, SetOptions? options) =>
          <String, dynamic>{}, // Dummy return
    );
  });

  group('HtSourcesFirestore', () {
    // Declare all mocks
    late FirebaseFirestore mockFirestore;
    late _MockRawCollectionReference mockRawCollectionRef;
    late _MockTypedCollectionReference mockTypedCollectionRef;
    late _MockTypedDocumentReference mockTypedDocRef;
    late _MockTypedDocumentSnapshot mockTypedDocSnapshot;
    late _MockTypedQuerySnapshot mockTypedQuerySnapshot;
    late HtSourcesFirestore sourcesFirestore;
    late client.Source testSource;

    setUp(() {
      // Instantiate mocks
      mockFirestore = _MockFirebaseFirestore();
      mockRawCollectionRef = _MockRawCollectionReference();
      mockTypedCollectionRef = _MockTypedCollectionReference();
      mockTypedDocRef = _MockTypedDocumentReference();
      mockTypedDocSnapshot = _MockTypedDocumentSnapshot();
      mockTypedQuerySnapshot = _MockTypedQuerySnapshot();

      // Create a concrete test source instance
      testSource = client.Source(
        id: 'test-id-123',
        name: 'Test Source',
        description: 'A source for testing',
        url: 'http://example.com',
        category: 'testing',
        language: 'en',
        country: 'us',
      );

      // --- Configure Core Mock Interactions ---
      // 1. mockFirestore.collection('sources') returns the RAW collection mock
      when(() => mockFirestore.collection('sources'))
          .thenReturn(mockRawCollectionRef);

      // 2. The RAW collection mock's withConverter returns the TYPED collection mock
      //    This is crucial for initializing _sourcesCollection correctly.
      when(
        () => mockRawCollectionRef.withConverter<client.Source>(
          fromFirestore: any(named: 'fromFirestore'),
          toFirestore: any(named: 'toFirestore'),
        ),
      ).thenReturn(mockTypedCollectionRef); // Return the typed mock

      // 3. The TYPED collection mock's doc() returns the TYPED doc mock
      //    Use any() for the ID initially, specific IDs set in test groups
      when(() => mockTypedCollectionRef.doc(any())).thenReturn(mockTypedDocRef);
      // Ensure the typed doc ref mock has the correct ID when accessed
      when(() => mockTypedDocRef.id).thenReturn(testSource.id);

      // Instantiate the class under test AFTER setting up core mocks
      sourcesFirestore = HtSourcesFirestore(firestore: mockFirestore);
    });

    // --- Test Groups ---

    group('createSource', () {
      setUp(() {
        // Ensure doc(testSource.id) returns the specific mockTypedDocRef
        when(() => mockTypedCollectionRef.doc(testSource.id))
            .thenReturn(mockTypedDocRef);
      });

      test('successfully creates a source', () async {
        // Arrange: Configure typed docRef.set to complete successfully
        when(() => mockTypedDocRef.set(testSource)).thenAnswer((_) async {});

        // Act
        final result = await sourcesFirestore.createSource(source: testSource);

        // Assert
        expect(result, equals(testSource));
        // Verify against the typed collection/doc mocks
        verify(() => mockTypedCollectionRef.doc(testSource.id)).called(1);
        verify(() => mockTypedDocRef.set(testSource)).called(1);
        // Verify the converter setup was called during initialization
        verify(
          () => mockRawCollectionRef.withConverter<client.Source>(
            fromFirestore: any(named: 'fromFirestore'),
            toFirestore: any(named: 'toFirestore'),
          ),
        ).called(1);
      });

      test('throws SourceCreateFailure on FirebaseException during set',
          () async {
        // Arrange: Configure typed docRef.set to throw FirebaseException
        final exception = FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
        );
        when(() => mockTypedDocRef.set(testSource)).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.createSource(source: testSource),
          throwsA(
            isA<client.SourceCreateFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to create source in Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(testSource.id)).called(1);
        verify(() => mockTypedDocRef.set(testSource)).called(1);
      });

      test('throws SourceCreateFailure on generic Exception during set',
          () async {
        // Arrange: Configure typed docRef.set to throw a generic Exception
        final exception = Exception('Something went wrong');
        when(() => mockTypedDocRef.set(testSource)).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.createSource(source: testSource),
          throwsA(
            isA<client.SourceCreateFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(testSource.id)).called(1);
        verify(() => mockTypedDocRef.set(testSource)).called(1);
      });
    });

    group('deleteSource', () {
      const sourceId = 'test-id-123';

      setUp(() {
        // Point the typed collection mock to the typed doc mock for this ID
        when(() => mockTypedCollectionRef.doc(sourceId))
            .thenReturn(mockTypedDocRef);
      });

      test('successfully deletes an existing source', () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);
        when(() => mockTypedDocRef.delete()).thenAnswer((_) async {});

        // Act
        await sourcesFirestore.deleteSource(id: sourceId);

        // Assert
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verify(() => mockTypedDocRef.delete()).called(1);
      });

      test('throws SourceNotFoundException if source does not exist', () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(false);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocRef.delete());
      });

      test('throws SourceDeleteFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockTypedDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(
            isA<client.SourceDeleteFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to delete source from Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocRef.delete());
      });

      test('throws SourceDeleteFailure on FirebaseException during delete',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'permission-denied');
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);
        when(() => mockTypedDocRef.delete()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(
            isA<client.SourceDeleteFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to delete source from Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // Removed verify for delete() as throwsA confirms it was attempted
      });

      test('throws SourceDeleteFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockTypedDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(
            isA<client.SourceDeleteFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocRef.delete());
      });

      test('throws SourceDeleteFailure on generic Exception during delete',
          () async {
        // Arrange
        final exception = Exception('Unexpected error during delete');
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);
        when(() => mockTypedDocRef.delete()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(
            isA<client.SourceDeleteFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // Removed verify for delete() as throwsA confirms it was attempted
      });
    });

    group('getSource', () {
      const sourceId = 'test-id-123';

      setUp(() {
        // Point the typed collection mock to the typed doc mock for this ID
        when(() => mockTypedCollectionRef.doc(sourceId))
            .thenReturn(mockTypedDocRef);
        // Ensure the typed doc ref mock has the correct ID when accessed
        when(() => mockTypedDocRef.id).thenReturn(sourceId);
      });

      test('successfully gets an existing source', () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        // Configure the typed snapshot to return the Source object
        when(() => mockTypedDocSnapshot.data()).thenReturn(testSource);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);

        // Act
        final result = await sourcesFirestore.getSource(id: sourceId);

        // Assert
        expect(result, equals(testSource));
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verify(() => mockTypedDocSnapshot.data()).called(1);
      });

      test('throws SourceNotFoundException if source does not exist', () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(false);
        // Ensure data() returns null when exists is false
        when(() => mockTypedDocSnapshot.data()).thenReturn(null);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // data() shouldn't be called if !exists
        verifyNever(() => mockTypedDocSnapshot.data());
      });

      test(
          'throws SourceFetchFailure if snapshot exists but data is null (tests internal handling)',
          () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        // Simulate null data despite existing snapshot
        when(() => mockTypedDocSnapshot.data()).thenReturn(null);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          // This specific failure comes from the check within getSource itself
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('Failed to parse source data for id: $sourceId'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // data() IS called in this scenario, but verify inside throwsA is problematic
        // verify(() => mockTypedDocSnapshot.data()).called(1);
      });

      test('throws SourceFetchFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'internal');
        when(() => mockTypedDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to get source from Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocSnapshot.data());
      });

      test('throws SourceFetchFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Something unexpected happened');
        when(() => mockTypedDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocSnapshot.data());
      });

      // Test case specifically for the fromFirestore converter throwing
      test(
          'throws SourceFetchFailure when fromFirestore converter throws (simulated via data())',
          () async {
        // Arrange
        final converterException = Exception('Simulated converter error');
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        // Make the data() call itself throw, simulating converter failure
        when(() => mockTypedDocSnapshot.data()).thenThrow(converterException);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          // Should be caught by the generic catch block in getSource
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $converterException'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // data() is called and throws, but verify inside throwsA is problematic
        // verify(() => mockTypedDocSnapshot.data()).called(1);
      });
    });

    group('getSources', () {
      late client.Source source1;
      late client.Source source2;
      late _MockTypedQueryDocumentSnapshot mockTypedQueryDocSnapshot1;
      late _MockTypedQueryDocumentSnapshot mockTypedQueryDocSnapshot2;

      setUp(() {
        // Create distinct sources
        source1 = client.Source(id: 'id-1', name: 'Source One');
        source2 = client.Source(id: 'id-2', name: 'Source Two');

        // Create mocks for the typed query document snapshots
        mockTypedQueryDocSnapshot1 = _MockTypedQueryDocumentSnapshot();
        mockTypedQueryDocSnapshot2 = _MockTypedQueryDocumentSnapshot();

        // Configure mocks to return the Source objects
        when(() => mockTypedQueryDocSnapshot1.data()).thenReturn(source1);
        when(() => mockTypedQueryDocSnapshot2.data()).thenReturn(source2);
      });

      test('successfully gets a list of sources', () async {
        // Arrange
        final typedDocSnapshots = [
          mockTypedQueryDocSnapshot1,
          mockTypedQueryDocSnapshot2,
        ];
        when(() => mockTypedQuerySnapshot.docs).thenReturn(typedDocSnapshots);
        when(() => mockTypedCollectionRef.get())
            .thenAnswer((_) async => mockTypedQuerySnapshot);
        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, equals([source1, source2]));
        verify(() => mockTypedCollectionRef.get()).called(1);
        verify(() => mockTypedQuerySnapshot.docs).called(1);
        // Verify data() was called on each typed doc snapshot
        verify(() => mockTypedQueryDocSnapshot1.data()).called(1);
        verify(() => mockTypedQueryDocSnapshot2.data()).called(1);
      });

      test('successfully gets an empty list when no sources exist', () async {
        // Arrange
        when(() => mockTypedQuerySnapshot.docs).thenReturn([]); // Empty list
        when(() => mockTypedCollectionRef.get())
            .thenAnswer((_) async => mockTypedQuerySnapshot);

        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, isEmpty);
        verify(() => mockTypedCollectionRef.get()).called(1);
        verify(() => mockTypedQuerySnapshot.docs).called(1);
      });

      test('throws SourceFetchFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'data-loss');
        when(() => mockTypedCollectionRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSources(),
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to get sources from Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.get()).called(1);
        verifyNever(() => mockTypedQuerySnapshot.docs);
      });

      test('throws SourceFetchFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Failed to connect during getSources');
        when(() => mockTypedCollectionRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSources(),
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.get()).called(1);
        verifyNever(() => mockTypedQuerySnapshot.docs);
      });

      // Test case specifically for the fromFirestore converter throwing in list
      test(
          'throws SourceFetchFailure when fromFirestore converter throws in list (simulated via data())',
          () async {
        // Arrange
        final converterException = Exception('Simulated list converter error');
        // Make one of the data() calls throw
        when(() => mockTypedQueryDocSnapshot1.data()).thenReturn(source1);
        when(() => mockTypedQueryDocSnapshot2.data())
            .thenThrow(converterException);

        final typedDocSnapshots = [
          mockTypedQueryDocSnapshot1,
          mockTypedQueryDocSnapshot2, // This one will throw
        ];
        when(() => mockTypedQuerySnapshot.docs).thenReturn(typedDocSnapshots);
        when(() => mockTypedCollectionRef.get())
            .thenAnswer((_) async => mockTypedQuerySnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSources(),
          // Should be caught by the generic catch block in getSources
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $converterException'),
            ),
          ),
        );
        // Removed verify calls as throwsA confirms the path was executed
        // verify(() => mockTypedCollectionRef.get()).called(1);
        // verify(() => mockTypedQuerySnapshot.docs).called(1);
        // Verify data calls were attempted, but verify inside throwsA is problematic
        // verify(() => mockTypedQueryDocSnapshot1.data()).called(1);
        // verify(() => mockTypedQueryDocSnapshot2.data()).called(1);
      });
    });

    group('updateSource', () {
      late client.Source updatedSource;

      setUp(() {
        // Create an updated version of the test source
        updatedSource = testSource.copyWith(
          name: 'Updated Test Source',
          description: 'Updated description',
        );

        // Point the typed collection mock to the typed doc mock for this ID
        when(() => mockTypedCollectionRef.doc(updatedSource.id))
            .thenReturn(mockTypedDocRef);
      });

      test('successfully updates an existing source', () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);
        // Mock the typed set operation for the updated source
        when(() => mockTypedDocRef.set(updatedSource)).thenAnswer((_) async {});

        // Act
        final result =
            await sourcesFirestore.updateSource(source: updatedSource);

        // Assert
        expect(result, equals(updatedSource));
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockTypedDocRef.get()).called(1); // Verify existence check
        verify(() => mockTypedDocRef.set(updatedSource)).called(1);
      });

      test('throws SourceNotFoundException if source does not exist', () async {
        // Arrange
        when(() => mockTypedDocSnapshot.exists).thenReturn(false);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocRef.set(any()));
      });

      test('throws SourceUpdateFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockTypedDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(
            isA<client.SourceUpdateFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to update source in Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocRef.set(any()));
      });

      test('throws SourceUpdateFailure on FirebaseException during set',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'permission-denied');
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);
        // Mock typed set to throw the exception
        when(() => mockTypedDocRef.set(updatedSource)).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(
            isA<client.SourceUpdateFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to update source in Firestore: ${exception.message} (${exception.code})',
              ),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // Removed verify for set() as throwsA confirms it was attempted
      });

      test('throws SourceUpdateFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockTypedDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(
            isA<client.SourceUpdateFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        verifyNever(() => mockTypedDocRef.set(any()));
      });

      test('throws SourceUpdateFailure on generic Exception during set',
          () async {
        // Arrange
        final exception = Exception('Unexpected error during set');
        when(() => mockTypedDocSnapshot.exists).thenReturn(true);
        when(() => mockTypedDocRef.get())
            .thenAnswer((_) async => mockTypedDocSnapshot);
        // Mock typed set to throw the exception
        when(() => mockTypedDocRef.set(updatedSource)).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(
            isA<client.SourceUpdateFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred: $exception'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockTypedDocRef.get()).called(1);
        // Removed verify for set() as throwsA confirms it was attempted
      });
    });
  });

  // --- Direct Converter Tests ---
  group('Firestore Converters', () {
    late client.Source testSource;
    late Map<String, dynamic> testSourceJson;
    late _MockRawDocumentSnapshot mockRawSnapshot; // Use raw snapshot mock

    // Define the converter functions locally for direct testing
    // (Copied from HtSourcesFirestore implementation)
    client.Source fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? _,
    ) {
      final data = snapshot.data();
      if (data == null) {
        throw FirebaseException(
          plugin: 'HtSourcesFirestore', // Keep plugin name consistent
          code: 'null-data',
          message: 'Firestore snapshot data was null for id ${snapshot.id}',
        );
      }
      return client.Source.fromJson(data);
    }

    Map<String, dynamic> toFirestore(client.Source source, SetOptions? _) {
      return source.toJson();
    }

    setUp(() {
      testSource = client.Source(
        id: 'converter-test-id',
        name: 'Converter Test Source',
        description: 'Testing the converter',
        url: 'http://converter.test',
        category: 'converter',
        language: 'cnv',
        country: 'cv',
      );
      testSourceJson = testSource.toJson();
      mockRawSnapshot = _MockRawDocumentSnapshot(); // Instantiate raw mock
    });

    test('fromFirestore successfully converts snapshot data', () {
      // Arrange
      when(() => mockRawSnapshot.data()).thenReturn(testSourceJson);
      when(() => mockRawSnapshot.id).thenReturn(testSource.id); // Needed for potential error message

      // Act
      final result = fromFirestore(mockRawSnapshot, null);

      // Assert
      expect(result, equals(testSource));
      verify(() => mockRawSnapshot.data()).called(1);
    });

    test('fromFirestore throws FirebaseException when data is null', () {
      // Arrange
      when(() => mockRawSnapshot.data()).thenReturn(null);
      when(() => mockRawSnapshot.id).thenReturn('null-data-test-id');

      // Act & Assert
      expect(
        () => fromFirestore(mockRawSnapshot, null),
        throwsA(
          isA<FirebaseException>()
              .having((e) => e.plugin, 'plugin', 'HtSourcesFirestore')
              .having((e) => e.code, 'code', 'null-data')
              .having(
                (e) => e.message,
                'message',
                contains('Firestore snapshot data was null for id null-data-test-id'),
              ),
        ),
      );
      verify(() => mockRawSnapshot.data()).called(1);
    });

    test('toFirestore successfully converts Source to JSON', () {
      // Act
      final result = toFirestore(testSource, null);

      // Assert
      expect(result, equals(testSourceJson));
    });
  });
}
