//
// ignore_for_file: subtype_of_sealed_class, lines_longer_than_80_chars

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_sources_client/ht_sources_client.dart' as client;
import 'package:ht_sources_firestore/src/ht_sources_firestore.dart';
import 'package:mocktail/mocktail.dart';

// Mocks for Firestore classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// Mock Source for comparison (optional, but can be useful)
class MockSource extends Mock implements client.Source {}

void main() {
  group('HtSourcesFirestore', () {
    late FirebaseFirestore mockFirestore;
    late CollectionReference<Map<String, dynamic>> mockSourcesCollection;
    late DocumentReference<Map<String, dynamic>> mockDocumentReference;
    late HtSourcesFirestore sourcesFirestore;

    // Sample Source data for testing
    final testSource = client.Source(
      id: 'test-id-123',
      name: 'Test Source Name',
      description: 'Test Description',
      url: 'http://test.example.com',
      category: 'technology',
      language: 'en',
      country: 'us',
    );
    final testSourceJson = testSource.toJson();

    setUp(() {
      // Register fallback values for argument matchers if needed
      // Example: registerFallbackValue(MockSource());

      mockFirestore = MockFirebaseFirestore();
      mockSourcesCollection = MockCollectionReference();
      mockDocumentReference = MockDocumentReference();

      // Setup Firestore mock interactions
      when(() => mockFirestore.collection('sources'))
          .thenReturn(mockSourcesCollection);
      when(() => mockSourcesCollection.doc(any()))
          .thenReturn(mockDocumentReference);
      // Default success for set/update/delete, override in specific tests
      when(() => mockDocumentReference.set(any()))
          .thenAnswer((_) async => Future.value());
      when(() => mockDocumentReference.update(any()))
          .thenAnswer((_) async => Future.value());
      when(() => mockDocumentReference.delete())
          .thenAnswer((_) async => Future.value());
      // Default setup for get() used in delete/update checks
      when(() => mockDocumentReference.get())
          .thenAnswer((_) async => MockDocumentSnapshot());

      sourcesFirestore = HtSourcesFirestore(firestore: mockFirestore);
    });

    group('createSource', () {
      test('successfully creates source and returns it', () async {
        // Arrange
        when(() => mockSourcesCollection.doc(testSource.id))
            .thenReturn(mockDocumentReference);
        when(() => mockDocumentReference.set(testSourceJson))
            .thenAnswer((_) async => Future.value()); // Explicit success setup

        // Act
        final result = await sourcesFirestore.createSource(source: testSource);

        // Assert
        expect(result, equals(testSource));
        verify(() => mockFirestore.collection('sources')).called(1);
        verify(() => mockSourcesCollection.doc(testSource.id)).called(1);
        verify(() => mockDocumentReference.set(testSourceJson)).called(1);
      });

      test('throws SourceCreateFailure on FirebaseException during set',
          () async {
        // Arrange
        final firebaseException = FirebaseException(
          plugin: 'firestore',
          code: 'unavailable',
          message: 'Firestore is unavailable',
        );
        when(() => mockSourcesCollection.doc(testSource.id))
            .thenReturn(mockDocumentReference);
        when(() => mockDocumentReference.set(testSourceJson))
            .thenThrow(firebaseException);

        // Act & Assert
        expect(
          () async => sourcesFirestore.createSource(source: testSource),
          throwsA(
            isA<client.SourceCreateFailure>().having(
              (e) => e.message,
              'message',
              contains(firebaseException.message),
            ),
          ),
        );
        verify(() => mockDocumentReference.set(testSourceJson)).called(1);
      });

      test('throws SourceCreateFailure on generic Exception during set',
          () async {
        // Arrange
        final exception = Exception('Something went wrong');
        when(() => mockSourcesCollection.doc(testSource.id))
            .thenReturn(mockDocumentReference);
        when(() => mockDocumentReference.set(testSourceJson))
            .thenThrow(exception);

        // Act & Assert
        expect(
          () async => sourcesFirestore.createSource(source: testSource),
          throwsA(
            isA<client.SourceCreateFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'),
            ),
          ),
        );
        verify(() => mockDocumentReference.set(testSourceJson)).called(1);
      });
    });

    group('deleteSource', () {
      const testId = 'test-id-to-delete';
      late MockDocumentSnapshot mockSnapshot;

      setUp(() {
        mockSnapshot = MockDocumentSnapshot();
        // Point the specific doc ID to the shared mock reference
        when(() => mockSourcesCollection.doc(testId))
            .thenReturn(mockDocumentReference);
        // Link the get() call on that reference to our snapshot mock
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockSnapshot);
        // Default setup: document exists and delete succeeds
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockDocumentReference.delete())
            .thenAnswer((_) async => Future.value());
      });

      test('successfully deletes source when document exists', () async {
        // Arrange (Defaults are set in setUp)

        // Act
        await sourcesFirestore.deleteSource(id: testId);

        // Assert
        verify(() => mockSourcesCollection.doc(testId)).called(1);
        verify(() => mockDocumentReference.get())
            .called(1); // Verify existence check
        verify(() => mockDocumentReference.delete()).called(1);
      });

      test('throws SourceNotFoundException when document does not exist',
          () async {
        // Arrange
        when(() => mockSnapshot.exists).thenReturn(false);

        // Act & Assert
        expect(
          () async => sourcesFirestore.deleteSource(id: testId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(
          () => mockDocumentReference.delete(),
        ); // Delete should not be called
      });

      test('throws SourceDeleteFailure on FirebaseException during get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockDocumentReference.get()).thenThrow(firebaseException);

        // Act & Assert
        expect(
          () async => sourcesFirestore.deleteSource(id: testId),
          throwsA(isA<client.SourceDeleteFailure>()),
        );
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockDocumentReference.delete());
      });

      test('throws SourceDeleteFailure on FirebaseException during delete',
          () async {
        // Arrange: Full local setup for complete isolation
        final localFirestore = MockFirebaseFirestore();
        final localCollectionRef = MockCollectionReference();
        final localDocRef = MockDocumentReference();
        final localSnapshot = MockDocumentSnapshot();
        final localSourcesFirestore =
            HtSourcesFirestore(firestore: localFirestore);
        final firebaseException = FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
        );

        when(() => localFirestore.collection('sources'))
            .thenReturn(localCollectionRef);
        when(() => localCollectionRef.doc(testId)).thenReturn(localDocRef);
        when(localDocRef.get).thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists)
            .thenReturn(true); // Ensure get() passes
        when(localDocRef.delete)
            .thenThrow(firebaseException); // delete() throws

        // Act & Assert
        // Use expectLater for futures throwing exceptions
        final future = localSourcesFirestore.deleteSource(id: testId);
        await expectLater(future, throwsA(isA<client.SourceDeleteFailure>()));

        // Verify interactions on the local mocks AFTER awaiting the future
        verify(localDocRef.get).called(1);
        verify(localDocRef.delete).called(1);
      });

      test('throws SourceDeleteFailure on generic Exception during delete',
          () async {
        // Arrange: Full local setup for complete isolation
        final localFirestore = MockFirebaseFirestore();
        final localCollectionRef = MockCollectionReference();
        final localDocRef = MockDocumentReference();
        final localSnapshot = MockDocumentSnapshot();
        final localSourcesFirestore =
            HtSourcesFirestore(firestore: localFirestore);
        final exception = Exception('Network error');

        when(() => localFirestore.collection('sources'))
            .thenReturn(localCollectionRef);
        when(() => localCollectionRef.doc(testId)).thenReturn(localDocRef);
        when(localDocRef.get).thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists)
            .thenReturn(true); // Ensure get() passes
        when(localDocRef.delete).thenThrow(exception); // delete() throws

        // Act & Assert
        // Use expectLater for futures throwing exceptions
        final future = localSourcesFirestore.deleteSource(id: testId);
        await expectLater(
          future,
          throwsA(
            isA<client.SourceDeleteFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'),
            ),
          ),
        );

        // Verify interactions on the local mocks AFTER awaiting the future
        verify(localDocRef.get).called(1);
        verify(localDocRef.delete).called(1);
      });
    });

    group('getSource', () {
      const testId = 'test-id-get';
      late MockDocumentSnapshot mockSnapshot;

      setUp(() {
        mockSnapshot = MockDocumentSnapshot();
        // Point the specific doc ID to the shared mock reference
        when(() => mockSourcesCollection.doc(testId))
            .thenReturn(mockDocumentReference);
        // Link the get() call on that reference to our snapshot mock
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockSnapshot);
        // Default setup: document exists and has data
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn(testSourceJson);
      });

      test('successfully gets source when document exists and data is valid',
          () async {
        // Arrange (Defaults are set in setUp)

        // Act
        final result = await sourcesFirestore.getSource(id: testId);

        // Assert
        expect(result, equals(testSource)); // Use the predefined testSource
        verify(() => mockSourcesCollection.doc(testId)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verify(() => mockSnapshot.data()).called(1);
      });

      test('throws SourceNotFoundException when document does not exist',
          () async {
        // Arrange
        when(() => mockSnapshot.exists).thenReturn(false);
        // Ensure data() is not called if exists is false
        when(() => mockSnapshot.data()).thenReturn(null);

        // Act & Assert
        expect(
          () async => sourcesFirestore.getSource(id: testId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockSnapshot.data()); // data() should not be called
      });

      test('throws SourceFetchFailure when document data is null', () async {
        // Arrange: Full local setup for complete isolation
        final localFirestore = MockFirebaseFirestore();
        final localCollectionRef = MockCollectionReference();
        final localDocRef = MockDocumentReference();
        final localSnapshot = MockDocumentSnapshot();
        final localSourcesFirestore =
            HtSourcesFirestore(firestore: localFirestore);

        when(() => localFirestore.collection('sources'))
            .thenReturn(localCollectionRef);
        when(() => localCollectionRef.doc(testId)).thenReturn(localDocRef);
        when(localDocRef.get).thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists).thenReturn(true);
        when(localSnapshot.data).thenReturn(null); // Simulate null data

        // Act & Assert
        final future = localSourcesFirestore.getSource(id: testId);
        await expectLater(
          future,
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('Firestore document data was null'),
            ),
          ),
        );
        // Verify interactions on local mocks
        verify(localDocRef.get).called(1);
        verify(localSnapshot.data).called(1);
      });

      test(
          'throws SourceFetchFailure when document data is invalid (parsing error)',
          () async {
        // Arrange: Full local setup for complete isolation
        final localFirestore = MockFirebaseFirestore();
        final localCollectionRef = MockCollectionReference();
        final localDocRef = MockDocumentReference();
        final localSnapshot = MockDocumentSnapshot();
        final localSourcesFirestore =
            HtSourcesFirestore(firestore: localFirestore);
        final invalidData = {
          'id': testId,
          'invalid_field': 'causes_error',
        }; // Missing 'name'

        when(() => localFirestore.collection('sources'))
            .thenReturn(localCollectionRef);
        when(() => localCollectionRef.doc(testId)).thenReturn(localDocRef);
        when(localDocRef.get).thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists).thenReturn(true);
        when(localSnapshot.data)
            .thenReturn(invalidData); // Simulate invalid data

        // Act & Assert
        final future = localSourcesFirestore.getSource(id: testId);
        await expectLater(
          future,
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('Failed to parse source data'),
            ),
          ),
        );
        // Verify interactions on local mocks
        verify(localDocRef.get).called(1);
        verify(localSnapshot.data).called(1);
      });

      test('throws SourceFetchFailure on FirebaseException during get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockDocumentReference.get()).thenThrow(firebaseException);

        // Act & Assert
        expect(
          () async => sourcesFirestore.getSource(id: testId),
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(
          () => mockSnapshot.exists,
        ); // Shouldn't get to snapshot checks
        verifyNever(() => mockSnapshot.data());
      });

      test('throws SourceFetchFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockDocumentReference.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () async => sourcesFirestore.getSource(id: testId),
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'),
            ),
          ),
        );
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockSnapshot.exists);
        verifyNever(() => mockSnapshot.data());
      });
    });

    group('getSources', () {
      late MockQuerySnapshot mockQuerySnapshot;
      late MockQueryDocumentSnapshot mockQueryDocSnapshot1;
      late MockQueryDocumentSnapshot mockQueryDocSnapshot2;

      // Sample data for multiple sources
      final testSource1 = client.Source(id: 'id1', name: 'Source 1');
      final testSource2 = client.Source(id: 'id2', name: 'Source 2');
      final testSource1Json = testSource1.toJson();
      final testSource2Json = testSource2.toJson();

      setUp(() {
        mockQuerySnapshot = MockQuerySnapshot();
        mockQueryDocSnapshot1 = MockQueryDocumentSnapshot();
        mockQueryDocSnapshot2 = MockQueryDocumentSnapshot();

        // Link collection get() to the query snapshot
        when(() => mockSourcesCollection.get())
            .thenAnswer((_) async => mockQuerySnapshot);

        // Default setup: return two valid documents
        when(() => mockQuerySnapshot.docs).thenReturn([
          mockQueryDocSnapshot1,
          mockQueryDocSnapshot2,
        ]);
        when(() => mockQueryDocSnapshot1.id).thenReturn(testSource1.id);
        when(() => mockQueryDocSnapshot1.data()).thenReturn(testSource1Json);
        when(() => mockQueryDocSnapshot2.id).thenReturn(testSource2.id);
        when(() => mockQueryDocSnapshot2.data()).thenReturn(testSource2Json);
      });

      test('successfully gets list of sources', () async {
        // Arrange (Defaults set in setUp)

        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, equals([testSource1, testSource2]));
        verify(() => mockSourcesCollection.get()).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
        verify(() => mockQueryDocSnapshot1.data()).called(1);
        verify(() => mockQueryDocSnapshot2.data()).called(1);
      });

      test('returns empty list when no documents found', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]); // No docs

        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, isEmpty);
        verify(() => mockSourcesCollection.get()).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
      });

      test(
          'throws SourceFetchFailure when a document has invalid data (parsing error)',
          () async {
        // Arrange
        final invalidData = {'id': 'id2', 'invalid': true};
        when(() => mockQueryDocSnapshot1.data()).thenReturn(testSource1Json);
        when(() => mockQueryDocSnapshot2.data())
            .thenReturn(invalidData); // Doc 2 is invalid

        // Act & Assert
        final future = sourcesFirestore.getSources();
        await expectLater(
          future,
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains(
                'Failed to parse source data for doc id: ${testSource2.id}',
              ),
            ),
          ),
        );
        verify(() => mockSourcesCollection.get()).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
        verify(() => mockQueryDocSnapshot1.data()).called(1);
        verify(() => mockQueryDocSnapshot2.data()).called(1);
      });

      test(
          'throws SourceFetchFailure on FirebaseException during collection get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockSourcesCollection.get()).thenThrow(firebaseException);

        // Act & Assert
        final future = sourcesFirestore.getSources();
        await expectLater(
          future,
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockSourcesCollection.get()).called(1);
        verifyNever(
          () => mockQuerySnapshot.docs,
        ); // Should fail before accessing docs
      });

      test(
          'throws SourceFetchFailure on generic Exception during collection get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockSourcesCollection.get()).thenThrow(exception);

        // Act & Assert
        final future = sourcesFirestore.getSources();
        await expectLater(
          future,
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'),
            ),
          ),
        );
        verify(() => mockSourcesCollection.get()).called(1);
        verifyNever(() => mockQuerySnapshot.docs);
      });
    });

    group('updateSource', () {
      late client.Source updatedSource;
      late Map<String, dynamic> updatedSourceJson;
      late MockDocumentSnapshot mockSnapshot;

      setUp(() {
        updatedSource = testSource.copyWith(name: 'Updated Source Name');
        updatedSourceJson = updatedSource.toJson();
        mockSnapshot = MockDocumentSnapshot();

        // Point the specific doc ID to the shared mock reference
        when(() => mockSourcesCollection.doc(updatedSource.id))
            .thenReturn(mockDocumentReference);
        // Link the get() call (for existence check) to our snapshot mock
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockSnapshot);
        // Default setup: document exists and set succeeds
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockDocumentReference.set(updatedSourceJson))
            .thenAnswer((_) async => Future.value());
      });

      test('successfully updates source and returns it', () async {
        // Arrange (Defaults set in setUp)

        // Act
        final result =
            await sourcesFirestore.updateSource(source: updatedSource);

        // Assert
        expect(result, equals(updatedSource));
        verify(() => mockSourcesCollection.doc(updatedSource.id)).called(1);
        verify(() => mockDocumentReference.get()).called(1); // Existence check
        verify(() => mockDocumentReference.set(updatedSourceJson)).called(1);
      });

      test('throws SourceNotFoundException when document does not exist',
          () async {
        // Arrange
        when(() => mockSnapshot.exists).thenReturn(false);

        // Act & Assert
        final future = sourcesFirestore.updateSource(source: updatedSource);
        await expectLater(
          future,
          throwsA(isA<client.SourceNotFoundException>()),
        );

        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(
          () => mockDocumentReference.set(any()),
        ); // Set should not be called
      });

      test('throws SourceUpdateFailure on FirebaseException during get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockDocumentReference.get()).thenThrow(firebaseException);

        // Act & Assert
        final future = sourcesFirestore.updateSource(source: updatedSource);
        await expectLater(future, throwsA(isA<client.SourceUpdateFailure>()));

        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockDocumentReference.set(any()));
      });

      test('throws SourceUpdateFailure on FirebaseException during set',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'permission-denied');
        when(() => mockSnapshot.exists).thenReturn(true); // Ensure get() passes
        when(() => mockDocumentReference.set(updatedSourceJson))
            .thenThrow(firebaseException);

        // Act & Assert
        final future = sourcesFirestore.updateSource(source: updatedSource);
        await expectLater(future, throwsA(isA<client.SourceUpdateFailure>()));

        verify(() => mockDocumentReference.get()).called(1);
        verify(() => mockDocumentReference.set(updatedSourceJson)).called(1);
      });

      test('throws SourceUpdateFailure on generic Exception during set',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockSnapshot.exists).thenReturn(true); // Ensure get() passes
        when(() => mockDocumentReference.set(updatedSourceJson))
            .thenThrow(exception);

        // Act & Assert
        final future = sourcesFirestore.updateSource(source: updatedSource);
        await expectLater(
          future,
          throwsA(
            isA<client.SourceUpdateFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'),
            ),
          ),
        );
        verify(() => mockDocumentReference.get()).called(1);
        verify(() => mockDocumentReference.set(updatedSourceJson)).called(1);
      });
    });
  });
}
