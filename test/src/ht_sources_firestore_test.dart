//
// ignore_for_file: subtype_of_sealed_class, lines_longer_than_80_chars

// Added for Future.value

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

// Add Mock for Query
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// Mock Source for comparison (optional, but can be useful)
class MockSource extends Mock implements client.Source {}

// Fallback values for mocktail argument matchers
class FakeSource extends Fake implements client.Source {}

class FakeGetOptions extends Fake implements GetOptions {}

class FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  // Register fallback values before any tests run
  setUpAll(() {
    registerFallbackValue(FakeSource());
    registerFallbackValue(FakeGetOptions());
    registerFallbackValue(FakeQueryDocumentSnapshot());
  });
  group('HtSourcesFirestore', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockSourcesCollection;
    late MockDocumentReference mockDocumentReference;
    // Add mock for Query used in getSources
    late MockQuery mockSourcesQuery;
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
      mockFirestore = MockFirebaseFirestore();
      mockSourcesCollection = MockCollectionReference();
      mockDocumentReference = MockDocumentReference();
      // Add mock for Query
      mockSourcesQuery = MockQuery();

      // Setup Firestore mock interactions
      when(() => mockFirestore.collection('sources'))
          .thenReturn(mockSourcesCollection);

      // Setup the base query chain used in getSources
      // This represents _firestore.collection('sources').orderBy('name')
      when(() => mockSourcesCollection.orderBy('name'))
          .thenReturn(mockSourcesQuery);
      // Mock the default behavior for limit, startAfterDocument, and get on the query
      // These will be overridden in specific getSources tests as needed
      when(() => mockSourcesQuery.limit(any())).thenReturn(mockSourcesQuery);
      when(() => mockSourcesQuery.startAfterDocument(any()))
          .thenReturn(mockSourcesQuery);
      // Default empty snapshot for query get
      final mockQuerySnapshot = MockQuerySnapshot();
      when(() => mockQuerySnapshot.docs).thenReturn([]); // Default empty docs
      when(() => mockSourcesQuery.get(any<GetOptions>()))
          .thenAnswer((_) async => mockQuerySnapshot);

      when(() => mockSourcesCollection.doc(any()))
          .thenReturn(mockDocumentReference);
      // Default success for set/update/delete, override in specific tests
      when(() => mockDocumentReference.set(any()))
          .thenAnswer((_) async => Future.value());
      when(
        () => mockDocumentReference.update(any()),
      ) // Keep for potential future use
          .thenAnswer((_) async => Future.value());
      when(() => mockDocumentReference.delete())
          .thenAnswer((_) async => Future.value());
      // Default setup for get() used in delete/update/getSource checks
      // Use any<GetOptions>() to match calls with GetOptions(source: Source.server)
      final mockDocSnapshot = MockDocumentSnapshot();
      when(() => mockDocSnapshot.exists).thenReturn(true); // Default exists
      when(() => mockDocumentReference.get(any<GetOptions>()))
          .thenAnswer((_) async => mockDocSnapshot);

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
        // Use expectLater for async functions throwing exceptions
        await expectLater(
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
        // Use any<GetOptions>() to match the implementation
        when(() => mockDocumentReference.get(any<GetOptions>()))
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
        // Verify existence check with GetOptions
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verify(() => mockDocumentReference.delete()).called(1);
      });

      test('throws SourceNotFoundException when document does not exist',
          () async {
        // Arrange
        when(() => mockSnapshot.exists).thenReturn(false);

        // Act & Assert
        // Use expectLater for async functions throwing exceptions
        await expectLater(
          () async => sourcesFirestore.deleteSource(id: testId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verifyNever(
          () => mockDocumentReference.delete(),
        ); // Delete should not be called
      });

      test('throws SourceDeleteFailure on FirebaseException during get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        // Throw when get(any<GetOptions>()) is called
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenThrow(firebaseException);

        // Act & Assert
        // Use expectLater for async functions throwing exceptions
        await expectLater(
          () async => sourcesFirestore.deleteSource(id: testId),
          throwsA(isA<client.SourceDeleteFailure>()),
        );
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
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
        // Mock get with GetOptions
        when(() => localDocRef.get(any<GetOptions>()))
            .thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists)
            .thenReturn(true); // Ensure get() passes
        when(localDocRef.delete)
            .thenThrow(firebaseException); // delete() throws

        // Act & Assert
        // Use expectLater for futures throwing exceptions
        final future = localSourcesFirestore.deleteSource(id: testId);
        await expectLater(future, throwsA(isA<client.SourceDeleteFailure>()));

        // Verify interactions on the local mocks AFTER awaiting the future
        verify(() => localDocRef.get(any<GetOptions>())).called(1);
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
        // Mock get with GetOptions
        when(() => localDocRef.get(any<GetOptions>()))
            .thenAnswer((_) async => localSnapshot);
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
        verify(() => localDocRef.get(any<GetOptions>())).called(1);
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
        // Use any<GetOptions>() to match the implementation
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenAnswer((_) async => mockSnapshot);
        // Default setup: document exists and has data
        when(() => mockSnapshot.exists).thenReturn(true);
        // Return the JSON *without* the ID, as the implementation adds it
        when(() => mockSnapshot.data())
            .thenReturn(Map.from(testSourceJson)..remove('id'));
        // Mock the snapshot ID separately
        when(() => mockSnapshot.id).thenReturn(testId);
      });

      test('successfully gets source when document exists and data is valid',
          () async {
        // Arrange
        // Create a source matching the testId for this group
        final expectedSource = client.Source(
          id: testId, // Use the correct ID for this test group
          name: 'Test Source Name',
          description: 'Test Description',
          url: 'http://test.example.com',
          category: 'technology',
          language: 'en',
          country: 'us',
        );
        // Ensure the mock returns data corresponding to expectedSource (without ID)
        when(() => mockSnapshot.data())
            .thenReturn(Map.from(expectedSource.toJson())..remove('id'));
        when(() => mockSnapshot.id).thenReturn(testId); // Ensure ID matches

        // Act
        final result = await sourcesFirestore.getSource(id: testId);

        // Assert
        // The implementation adds the ID during parsing, so the result matches
        expect(
          result,
          equals(expectedSource),
        ); // Compare against the correct source
        verify(() => mockSourcesCollection.doc(testId)).called(1);
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verify(() => mockSnapshot.data()).called(1);
        verify(() => mockSnapshot.id).called(1); // Verify ID was accessed
      });

      test('throws SourceNotFoundException when document does not exist',
          () async {
        // Arrange
        when(() => mockSnapshot.exists).thenReturn(false);
        // No need to mock data() when exists is false

        // Act & Assert
        // Use expectLater for async functions throwing exceptions
        await expectLater(
          () async => sourcesFirestore.getSource(id: testId),
          throwsA(isA<client.SourceNotFoundException>()),
        );
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verifyNever(() => mockSnapshot.data()); // data() should not be called
        verifyNever(() => mockSnapshot.id); // id should not be called
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
        // Mock get with GetOptions
        when(() => localDocRef.get(any<GetOptions>()))
            .thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists).thenReturn(true);
        when(localSnapshot.data).thenReturn(null); // Simulate null data
        // Mock ID even if data is null, as it might be checked before data()
        when(() => localSnapshot.id)
            .thenAnswer((_) => testId); // Use thenAnswer

        // Act & Assert
        final future = localSourcesFirestore.getSource(id: testId);
        await expectLater(
          future,
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              // Expect the specific message for null data
              contains(
                'Firestore document data was unexpectedly null for id: $testId',
              ),
            ),
          ),
        );
        // Verify interactions on local mocks
        verify(() => localDocRef.get(any<GetOptions>())).called(1);
        verify(localSnapshot.data).called(1);
        // ID is not accessed when data is null, so no verification needed here.
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
        // Invalid data *without* ID, as implementation adds it before parsing
        final invalidData = {'invalid_field': 'causes_error'}; // Missing 'name'

        when(() => localFirestore.collection('sources'))
            .thenReturn(localCollectionRef);
        when(() => localCollectionRef.doc(testId)).thenReturn(localDocRef);
        // Mock get with GetOptions
        when(() => localDocRef.get(any<GetOptions>()))
            .thenAnswer((_) async => localSnapshot);
        when(() => localSnapshot.exists).thenReturn(true);
        when(localSnapshot.data)
            .thenReturn(invalidData); // Simulate invalid data
        // Mock ID as it's added before parsing
        when(() => localSnapshot.id)
            .thenAnswer((_) => testId); // Use thenAnswer

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
        verify(() => localDocRef.get(any<GetOptions>())).called(1);
        verify(localSnapshot.data).called(1); // Verify method call
        verify(() => localSnapshot.id); // Verify getter access (no .called(1))
      });

      test('throws SourceFetchFailure on FirebaseException during get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        // Throw when get(any<GetOptions>()) is called
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenThrow(firebaseException);

        // Act & Assert
        // Use expectLater for async functions throwing exceptions
        await expectLater(
          () async => sourcesFirestore.getSource(id: testId),
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verifyNever(
          () => mockSnapshot.exists,
        ); // Shouldn't get to snapshot checks
        verifyNever(() => mockSnapshot.data());
      });

      test('throws SourceFetchFailure on generic Exception during get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        // Throw when get(any<GetOptions>()) is called
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenThrow(exception);

        // Act & Assert
        // Use expectLater for async functions throwing exceptions
        await expectLater(
          () async => sourcesFirestore.getSource(id: testId),
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'),
            ),
          ),
        );
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verifyNever(() => mockSnapshot.exists);
        verifyNever(() => mockSnapshot.data());
        verifyNever(() => mockSnapshot.id);
      });
    });

    group('getSources', () {
      late MockQuerySnapshot mockQuerySnapshot;
      late MockQueryDocumentSnapshot mockQueryDocSnapshot1;
      late MockQueryDocumentSnapshot mockQueryDocSnapshot2;
      // Add mock for the startAfterDocument lookup result
      late MockDocumentSnapshot mockStartAfterDocSnapshot; // Correct type

      // Sample data for multiple sources
      final testSource1 = client.Source(id: 'id1', name: 'Source 1');
      final testSource2 = client.Source(id: 'id2', name: 'Source 2');
      final testSource1Json = testSource1.toJson();
      final testSource2Json = testSource2.toJson();

      setUp(() {
        mockQuerySnapshot = MockQuerySnapshot();
        mockQueryDocSnapshot1 = MockQueryDocumentSnapshot();
        mockQueryDocSnapshot2 = MockQueryDocumentSnapshot();
        // Initialize the mock for the cursor doc snapshot
        mockStartAfterDocSnapshot = MockDocumentSnapshot(); // Correct type

        // Reset mocks for query chain for each test
        mockSourcesQuery = MockQuery();
        mockQuerySnapshot = MockQuerySnapshot();
        mockQueryDocSnapshot1 = MockQueryDocumentSnapshot();
        mockQueryDocSnapshot2 = MockQueryDocumentSnapshot();
        // mockStartAfterDocSnapshot is already initialized above

        // Base query setup
        when(() => mockSourcesCollection.orderBy('name'))
            .thenReturn(mockSourcesQuery);

        // Default query behavior (can be overridden)
        when(() => mockSourcesQuery.limit(any())).thenReturn(mockSourcesQuery);
        when(() => mockSourcesQuery.startAfterDocument(any()))
            .thenReturn(mockSourcesQuery);
        when(() => mockSourcesQuery.get(any<GetOptions>()))
            .thenAnswer((_) async => mockQuerySnapshot);

        // Default snapshot setup (can be overridden)
        when(() => mockQuerySnapshot.docs).thenReturn([
          mockQueryDocSnapshot1,
          mockQueryDocSnapshot2,
        ]);
        when(() => mockQueryDocSnapshot1.id).thenReturn(testSource1.id);
        // Return JSON without ID using a function
        when(() => mockQueryDocSnapshot1.data())
            .thenAnswer((_) => testSource1Json);
        when(() => mockQueryDocSnapshot2.id).thenReturn(testSource2.id);
        // Return JSON without ID using a function
        when(() => mockQueryDocSnapshot2.data())
            .thenAnswer((_) => testSource2Json);

        // Default setup for startAfterDocument lookup
        when(() => mockSourcesCollection.doc(any()))
            .thenReturn(mockDocumentReference); // Reuse general doc ref mock
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenAnswer((_) async => mockStartAfterDocSnapshot);
        when(() => mockStartAfterDocSnapshot.exists)
            .thenReturn(true); // Assume cursor doc exists by default
      });

      // --- Basic Fetching Tests ---

      test('successfully gets list of sources without parameters', () async {
        // Arrange (Defaults set in setUp)

        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, equals([testSource1, testSource2]));
        // Verify the query chain: collection -> orderBy -> get
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verifyNever(() => mockSourcesQuery.limit(any())); // No limit applied
        verifyNever(
          () => mockSourcesQuery.startAfterDocument(any()),
        ); // No cursor applied
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
        verify(() => mockQueryDocSnapshot1.data())
            .called(1); // Keep one verification
        verify(() => mockQueryDocSnapshot2.data()).called(1);
      });

      test('returns empty list when no documents found', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]); // No docs

        // Act
        final result = await sourcesFirestore.getSources();

        // Assert
        expect(result, isEmpty);
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
      });

      // --- Error Handling Tests ---

      test(
          'throws SourceFetchFailure when a document has invalid data (parsing error)',
          () async {
        // Arrange
        // More realistic invalid data (e.g., missing required 'name')
        final invalidData = {
          // 'id': testSource2.id, // ID is added by implementation
          'name': null, // Invalid: name is required
          'description': 'Valid description',
          'url': 'http://valid.url',
          'category': 'news',
          'language': 'fr',
          'country': 'fr',
        };
        when(() => mockQueryDocSnapshot1.data())
            .thenAnswer((_) => testSource1Json); // Use function
        when(() => mockQueryDocSnapshot2.id)
            .thenReturn(testSource2.id); // Need ID for error message
        when(() => mockQueryDocSnapshot2.data())
            .thenAnswer((_) => invalidData); // Doc 2 is invalid - Use function

        // Act & Assert
        final future = sourcesFirestore.getSources();
        // Use expectLater for async functions throwing exceptions
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
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
        verify(() => mockQuerySnapshot.docs).called(1);
        verify(() => mockQueryDocSnapshot1.data()).called(1);
        verify(() => mockQueryDocSnapshot2.data())
            .called(1); // Data accessed before error
        // Verify ID was accessed (at least once for parsing/error message)
        verify(() => mockQueryDocSnapshot2.id).called(greaterThanOrEqualTo(1));
      });

      test(
          'throws SourceFetchFailure on FirebaseException during collection get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        when(() => mockSourcesQuery.get(any<GetOptions>()))
            .thenThrow(firebaseException);

        // Act & Assert
        final future = sourcesFirestore.getSources();
        // Use expectLater for async functions throwing exceptions
        await expectLater(
          future,
          throwsA(isA<client.SourceFetchFailure>()),
        );
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
        verifyNever(
          () => mockQuerySnapshot.docs,
        ); // Should fail before accessing docs
      });

      test(
          'throws SourceFetchFailure on generic Exception during collection get',
          () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockSourcesQuery.get(any<GetOptions>()))
            .thenThrow(exception);

        // Act & Assert
        final future = sourcesFirestore.getSources();
        // Use expectLater for async functions throwing exceptions
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
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
        verifyNever(() => mockQuerySnapshot.docs);
      });

      test(
          'throws SourceFetchFailure on generic Exception during startAfterId doc get',
          () async {
        // Arrange
        final startId = testSource1.id;
        final exception = Exception('Network error');
        when(() => mockSourcesCollection.doc(startId))
            .thenReturn(mockDocumentReference);
        // Throw when getting the cursor document
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenThrow(exception);

        // Act & Assert
        final future = sourcesFirestore.getSources(startAfterId: startId);
        await expectLater(
          future,
          throwsA(
            isA<client.SourceFetchFailure>().having(
              (e) => e.message,
              'message',
              contains('An unexpected error occurred'), // Should bubble up
            ),
          ),
        );
        verify(() => mockSourcesCollection.doc(startId)).called(1);
        verify(() => mockDocumentReference.get(any<GetOptions>()))
            .called(1); // Attempted cursor get
        verifyNever(
          () => mockSourcesQuery.startAfterDocument(any()),
        ); // Never applied cursor
        verifyNever(
          () => mockSourcesQuery.get(any<GetOptions>()),
        ); // Never executed main query
      });

      // --- Pagination Tests ---

      test('successfully gets limited list of sources', () async {
        // Arrange
        const limit = 1;
        // Mock the limit call to return the same query mock
        when(() => mockSourcesQuery.limit(limit)).thenReturn(mockSourcesQuery);
        // Mock the snapshot to return only the first doc
        when(() => mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot1]);

        // Act
        final result = await sourcesFirestore.getSources(limit: limit);

        // Assert
        expect(result, hasLength(1)); // Check length
        expect(result, equals([testSource1])); // Check content
        // Verify the query chain: collection -> orderBy -> limit -> get
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verify(() => mockSourcesQuery.limit(limit))
            .called(1); // Verify limit was called
        verifyNever(() => mockSourcesQuery.startAfterDocument(any()));
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
      });

      test('successfully gets sources starting after a specific document ID',
          () async {
        // Arrange
        final startId = testSource1.id; // Start after the first source
        // Mock the startAfterDocument call
        // Use the specific snapshot mock for the cursor document
        when(
          () => mockSourcesQuery.startAfterDocument(mockStartAfterDocSnapshot),
        ).thenReturn(mockSourcesQuery);
        // Mock the snapshot to return only the second doc (as if paginated)
        when(() => mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot2]);
        // Ensure the cursor doc lookup is set up correctly
        when(() => mockSourcesCollection.doc(startId))
            .thenReturn(mockDocumentReference);
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenAnswer((_) async => mockStartAfterDocSnapshot);
        when(() => mockStartAfterDocSnapshot.exists).thenReturn(true);

        // Act
        final result = await sourcesFirestore.getSources(startAfterId: startId);

        // Assert
        expect(result, equals([testSource2]));
        // Verify the query chain: collection -> orderBy -> startAfterDocument -> get
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verify(() => mockSourcesCollection.doc(startId))
            .called(1); // Cursor doc lookup
        verify(() => mockDocumentReference.get(any<GetOptions>()))
            .called(1); // Cursor doc get
        verifyNever(() => mockSourcesQuery.limit(any()));
        // Verify startAfterDocument was called with the correct snapshot
        verify(
          () => mockSourcesQuery.startAfterDocument(mockStartAfterDocSnapshot),
        ).called(1);
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
      });

      test(
          'successfully gets limited sources starting after a specific document ID',
          () async {
        // Arrange
        final startId = testSource1.id;
        const limit = 1;
        // Mock limit and startAfterDocument calls
        when(() => mockSourcesQuery.limit(limit)).thenReturn(mockSourcesQuery);
        when(
          () => mockSourcesQuery.startAfterDocument(mockStartAfterDocSnapshot),
        ).thenReturn(mockSourcesQuery);
        // Mock snapshot to return only the second doc
        when(() => mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot2]);
        // Ensure cursor doc lookup is set up
        when(() => mockSourcesCollection.doc(startId))
            .thenReturn(mockDocumentReference);
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenAnswer((_) async => mockStartAfterDocSnapshot);
        when(() => mockStartAfterDocSnapshot.exists).thenReturn(true);

        // Act
        final result = await sourcesFirestore.getSources(
          limit: limit,
          startAfterId: startId,
        );

        // Assert
        expect(result, equals([testSource2]));
        // Verify the full query chain
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verify(() => mockSourcesQuery.limit(limit)).called(1);
        verify(() => mockSourcesCollection.doc(startId)).called(1);
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verify(
          () => mockSourcesQuery.startAfterDocument(mockStartAfterDocSnapshot),
        ).called(1);
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
      });

      test('fetches from beginning when startAfterId document does not exist',
          () async {
        // Arrange
        const startId = 'non-existent-id';
        // Mock the cursor doc lookup to return a non-existent snapshot
        when(() => mockSourcesCollection.doc(startId))
            .thenReturn(mockDocumentReference);
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenAnswer((_) async => mockStartAfterDocSnapshot);
        when(() => mockStartAfterDocSnapshot.exists)
            .thenReturn(false); // Cursor doc doesn't exist
        // Default query snapshot returns both docs
        when(() => mockQuerySnapshot.docs)
            .thenReturn([mockQueryDocSnapshot1, mockQueryDocSnapshot2]);

        // Act
        final result = await sourcesFirestore.getSources(startAfterId: startId);

        // Assert
        expect(result, equals([testSource1, testSource2])); // Returns all docs
        // Verify the query chain: collection -> orderBy -> get (startAfterDocument is NOT called)
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verify(() => mockSourcesCollection.doc(startId))
            .called(1); // Cursor doc lookup attempted
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verifyNever(() => mockSourcesQuery.limit(any()));
        verifyNever(
          () => mockSourcesQuery.startAfterDocument(any()),
        ); // Cursor NOT applied
        verify(() => mockSourcesQuery.get(any<GetOptions>()))
            .called(1); // Query executed
      });

      test('ignores invalid limit (<= 0) and fetches without limit', () async {
        // Arrange
        const limit = 0;
        // Default snapshot setup returns both docs
        when(() => mockQuerySnapshot.docs)
            .thenReturn([mockQueryDocSnapshot1, mockQueryDocSnapshot2]);

        // Act
        final result = await sourcesFirestore.getSources(limit: limit);

        // Assert
        expect(result, equals([testSource1, testSource2]));
        // Verify the query chain: collection -> orderBy -> get (limit is NOT called)
        verify(() => mockSourcesCollection.orderBy('name')).called(1);
        verifyNever(() => mockSourcesQuery.limit(any())); // Limit NOT applied
        verifyNever(() => mockSourcesQuery.startAfterDocument(any()));
        verify(() => mockSourcesQuery.get(any<GetOptions>())).called(1);
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
        // Use any<GetOptions>() to match implementation
        when(() => mockDocumentReference.get(any<GetOptions>()))
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
        verify(() => mockDocumentReference.get(any<GetOptions>()))
            .called(1); // Existence check
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

        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verifyNever(
          () => mockDocumentReference.set(any()),
        ); // Set should not be called
      });

      test('throws SourceUpdateFailure on FirebaseException during get',
          () async {
        // Arrange
        final firebaseException =
            FirebaseException(plugin: 'firestore', code: 'unavailable');
        // Throw when get(any<GetOptions>()) is called
        when(() => mockDocumentReference.get(any<GetOptions>()))
            .thenThrow(firebaseException);

        // Act & Assert
        final future = sourcesFirestore.updateSource(source: updatedSource);
        await expectLater(future, throwsA(isA<client.SourceUpdateFailure>()));

        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
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

        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
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
        verify(() => mockDocumentReference.get(any<GetOptions>())).called(1);
        verify(() => mockDocumentReference.set(updatedSourceJson)).called(1);
      });
    });
  });
}
