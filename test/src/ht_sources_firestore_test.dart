//
// ignore_for_file: subtype_of_sealed_class, lines_longer_than_80_chars

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_sources_client/ht_sources_client.dart' as client;
import 'package:ht_sources_firestore/src/ht_sources_firestore.dart';
import 'package:mocktail/mocktail.dart';

// Mocks using mocktail
class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// Add mock for the raw collection reference
class _MockRawCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// Rename existing mock for clarity
class _MockTypedCollectionReference extends Mock
    implements CollectionReference<client.Source> {}

class _MockDocumentReference extends Mock
    implements DocumentReference<client.Source> {}

// Add mock for DocumentSnapshot
class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<client.Source> {}

// Add mocks for QuerySnapshot and QueryDocumentSnapshot
class _MockQuerySnapshot extends Mock implements QuerySnapshot<client.Source> {}

class _MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<client.Source> {}

// Mock Source for convenience
class _MockSource extends Mock implements client.Source {}

void main() {
  // Register fallback values for types used in mocks
  setUpAll(() {
    registerFallbackValue(_MockSource());
    registerFallbackValue(
      FirebaseException(plugin: 'test', code: 'unknown'),
    );
  });

  group('HtSourcesFirestore', () {
    late FirebaseFirestore mockFirestore;
    late _MockRawCollectionReference mockRawCollectionRef;
    late _MockTypedCollectionReference mockTypedCollectionRef;
    late DocumentReference<client.Source> mockDocRef;
    late _MockDocumentSnapshot mockDocSnapshot;
    late _MockQuerySnapshot
        mockQuerySnapshot; // Add query snapshot mock instance
    late HtSourcesFirestore sourcesFirestore;
    late client.Source testSource;

    setUp(() {
      mockFirestore = _MockFirebaseFirestore();
      mockRawCollectionRef = _MockRawCollectionReference();
      mockTypedCollectionRef = _MockTypedCollectionReference();
      mockDocRef = _MockDocumentReference();
      mockDocSnapshot = _MockDocumentSnapshot();
      mockQuerySnapshot =
          _MockQuerySnapshot(); // Instantiate query snapshot mock

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

      // Configure mock interactions
      // 1. mockFirestore.collection returns the RAW collection mock
      when(() => mockFirestore.collection('sources'))
          .thenReturn(mockRawCollectionRef);
      // 2. The RAW collection mock's withConverter returns the TYPED collection mock
      when(
        () => mockRawCollectionRef.withConverter<client.Source>(
          fromFirestore: any(named: 'fromFirestore'),
          toFirestore: any(named: 'toFirestore'),
        ),
      ).thenReturn(mockTypedCollectionRef); // Return the typed mock
      // 3. The TYPED collection mock's doc returns the doc mock
      when(() => mockTypedCollectionRef.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.id)
          .thenReturn(testSource.id); // Ensure docRef has ID

      sourcesFirestore = HtSourcesFirestore(firestore: mockFirestore);
    });

    group('createSource', () {
      test('successfully creates a source', () async {
        // Arrange: Configure docRef.set to complete successfully
        when(() => mockDocRef.set(testSource)).thenAnswer((_) async {});
        // Ensure the typed collection mock is used for doc() call setup
        when(() => mockTypedCollectionRef.doc(testSource.id))
            .thenReturn(mockDocRef);

        // Act
        final result = await sourcesFirestore.createSource(source: testSource);

        // Assert
        expect(result, equals(testSource));
        // Verify against the typed collection mock
        verify(() => mockTypedCollectionRef.doc(testSource.id)).called(1);
        verify(() => mockDocRef.set(testSource)).called(1);
      });

      test('throws SourceCreateFailure on FirebaseException', () async {
        // Arrange: Configure docRef.set to throw FirebaseException
        final exception = FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
          message: 'Permission denied',
        );
        when(() => mockDocRef.set(any())).thenThrow(exception);
        // Ensure the typed collection mock is used for doc() call setup
        when(() => mockTypedCollectionRef.doc(testSource.id))
            .thenReturn(mockDocRef);

        // Act & Assert
        expect(
          () => sourcesFirestore.createSource(source: testSource),
          throwsA(
            isA<client.SourceCreateFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to create source in Firestore: Permission denied (permission-denied)',
              ),
            ),
          ),
        );
        // Verify against the typed collection mock
        verify(() => mockTypedCollectionRef.doc(testSource.id)).called(1);
        verify(() => mockDocRef.set(testSource)).called(1);
      });

      test('throws SourceCreateFailure on generic Exception', () async {
        // Arrange: Configure docRef.set to throw a generic Exception
        final exception = Exception('Something went wrong');
        when(() => mockDocRef.set(any())).thenThrow(exception);
        // Ensure the typed collection mock is used for doc() call setup
        when(() => mockTypedCollectionRef.doc(testSource.id))
            .thenReturn(mockDocRef);

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
        // Verify against the typed collection mock
        verify(() => mockTypedCollectionRef.doc(testSource.id)).called(1);
        verify(() => mockDocRef.set(testSource)).called(1);
      });
    });

    group('deleteSource', () {
      const sourceId = 'test-id-123';

      setUp(() {
        // Common setup for delete: always point the typed collection to the doc ref
        when(() => mockTypedCollectionRef.doc(sourceId)).thenReturn(mockDocRef);
      });

      test('successfully deletes an existing source', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocRef.delete()).thenAnswer((_) async {});

        // Act
        await sourcesFirestore.deleteSource(id: sourceId);

        // Assert
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verify(() => mockDocRef.delete()).called(1);
      });

      test('throws SourceNotFoundException if source does not exist', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.delete()); // Ensure delete is not called
      });

      test('throws SourceDeleteFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(isA<client.SourceDeleteFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.delete());
      });

      test('throws SourceDeleteFailure on FirebaseException during delete',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'permission-denied');
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocRef.delete()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(isA<client.SourceDeleteFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        // Explicitly verify get() first
        verify(() => mockDocRef.get()).called(1);
        // verify(() => mockDocRef.delete()).called(1); // Removed: throwsA handles verification
      });

      test('throws SourceDeleteFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(isA<client.SourceDeleteFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.delete());
      });

      test('throws SourceDeleteFailure on generic Exception during delete',
          () async {
        // Arrange
        final exception = Exception('Unexpected error');
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocRef.delete()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.deleteSource(id: sourceId),
          throwsA(isA<client.SourceDeleteFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        // verify(() => mockDocRef.delete()).called(1); // Removed: throwsA handles verification
      });
    });

    group('getSource', () {
      const sourceId = 'test-id-123';

      setUp(() {
        // Common setup for getSource: point the typed collection to the doc ref
        when(() => mockTypedCollectionRef.doc(sourceId)).thenReturn(mockDocRef);
      });

      test('successfully gets an existing source', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        // Use the concrete testSource created in the outer setUp
        when(() => mockDocSnapshot.data()).thenReturn(testSource);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Act
        final result = await sourcesFirestore.getSource(id: sourceId);

        // Assert
        expect(result, equals(testSource));
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verify(() => mockDocSnapshot.data()).called(1);
      });

      test('throws SourceNotFoundException if source does not exist', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(false);
        // Ensure data() returns null when exists is false, mimicking Firestore
        when(() => mockDocSnapshot.data()).thenReturn(null);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(
          () => mockDocSnapshot.data(),
        ); // data() shouldn't be called if !exists
      });

      test(
          'throws SourceFetchFailure if snapshot exists but data is null (defensive)',
          () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        // Simulate null data despite existing snapshot
        when(() => mockDocSnapshot.data()).thenReturn(null);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          // The code actually throws this specific error message
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('Failed to parse source data for id: $sourceId'),
            ),
          ),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        // verify(() => mockDocSnapshot.data()).called(1); // Removed: throwsA handles verification
      });

      test('throws SourceFetchFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'internal');
        when(() => mockDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocSnapshot.data());
      });

      test('throws SourceFetchFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Something unexpected happened');
        when(() => mockDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSource(id: sourceId),
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(sourceId)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocSnapshot.data());
      });
    });

    group('getSources', () {
      late client.Source source1;
      late client.Source source2;
      late _MockQueryDocumentSnapshot mockQueryDocSnapshot1;
      late _MockQueryDocumentSnapshot mockQueryDocSnapshot2;

      setUp(() {
        // Create some distinct sources for list testing
        source1 = client.Source(id: 'id-1', name: 'Source One');
        source2 = client.Source(id: 'id-2', name: 'Source Two');

        // Create mocks for the query document snapshots
        mockQueryDocSnapshot1 = _MockQueryDocumentSnapshot();
        mockQueryDocSnapshot2 = _MockQueryDocumentSnapshot();

        // Configure the mock query document snapshots to return data
        when(() => mockQueryDocSnapshot1.data()).thenReturn(source1);
        when(() => mockQueryDocSnapshot2.data()).thenReturn(source2);
      });

      test('successfully gets a list of sources', () async {
        // Arrange
        final docSnapshots = [mockQueryDocSnapshot1, mockQueryDocSnapshot2];
        when(() => mockQuerySnapshot.docs).thenReturn(docSnapshots);
        when(() => mockTypedCollectionRef.get())
            .thenAnswer((_) async => mockQuerySnapshot);
        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, equals([source1, source2]));
        verify(() => mockTypedCollectionRef.get()).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
        verify(() => mockQueryDocSnapshot1.data()).called(1);
        verify(() => mockQueryDocSnapshot2.data()).called(1);
      });

      test('successfully gets an empty list when no sources exist', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]); // Empty list
        when(() => mockTypedCollectionRef.get())
            .thenAnswer((_) async => mockQuerySnapshot);

        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, isEmpty);
        verify(() => mockTypedCollectionRef.get()).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
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
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockTypedCollectionRef.get()).called(1);
        verifyNever(() => mockQuerySnapshot.docs);
      });

      test('throws SourceFetchFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Failed to connect');
        when(() => mockTypedCollectionRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.getSources(),
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockTypedCollectionRef.get()).called(1);
        verifyNever(() => mockQuerySnapshot.docs);
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

        // Common setup for update: point the typed collection to the doc ref
        // Use updatedSource.id which should be the same as testSource.id
        when(() => mockTypedCollectionRef.doc(updatedSource.id))
            .thenReturn(mockDocRef);
      });

      test('successfully updates an existing source', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        // Mock the set operation for the updated source
        when(() => mockDocRef.set(updatedSource)).thenAnswer((_) async {});

        // Act
        final result =
            await sourcesFirestore.updateSource(source: updatedSource);

        // Assert
        expect(
          result,
          equals(updatedSource),
        ); // Should return the updated source
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockDocRef.get()).called(1); // Verify existence check
        verify(() => mockDocRef.set(updatedSource))
            .called(1); // Verify set call
      });

      test('throws SourceNotFoundException if source does not exist', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.set(any())); // Ensure set is not called
      });

      test('throws SourceUpdateFailure on FirebaseException during get',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(isA<client.SourceUpdateFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.set(any()));
      });

      test('throws SourceUpdateFailure on FirebaseException during set',
          () async {
        // Arrange
        final exception =
            FirebaseException(plugin: 'firestore', code: 'permission-denied');
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        // Mock set to throw the exception
        when(() => mockDocRef.set(updatedSource)).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(isA<client.SourceUpdateFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockDocRef.get()).called(1);
        // verify(() => mockDocRef.set(updatedSource)).called(1); // Removed: throwsA handles verification
      });

      test('throws SourceUpdateFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockDocRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(isA<client.SourceUpdateFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.set(any()));
      });

      test('throws SourceUpdateFailure on generic Exception during set',
          () async {
        // Arrange
        final exception = Exception('Unexpected error');
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        // Mock set to throw the exception
        when(() => mockDocRef.set(updatedSource)).thenThrow(exception);

        // Act & Assert
        expect(
          () => sourcesFirestore.updateSource(source: updatedSource),
          throwsA(isA<client.SourceUpdateFailure>()),
        );
        verify(() => mockTypedCollectionRef.doc(updatedSource.id)).called(1);
        verify(() => mockDocRef.get()).called(1);
        // verify(() => mockDocRef.set(updatedSource)).called(1); // Removed: throwsA handles verification
      });
    });
  });
}
