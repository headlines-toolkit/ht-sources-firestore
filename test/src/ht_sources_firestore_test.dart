//
// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_sources_firestore/ht_sources_firestore.dart';
import 'package:mocktail/mocktail.dart';

// Mock class for FirebaseFirestore
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('HtSourcesFirestore', () {
    // Declare mock instance
    late MockFirebaseFirestore mockFirestore;

    // Set up mock before each test
    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      // Add default stubbing if necessary for future tests
    });

    test('can be instantiated', () {
      // Pass the mock instance to the constructor
      expect(HtSourcesFirestore(firestore: mockFirestore), isNotNull);
    });

    // Add more tests here for each method (create, get, update, delete, etc.)
    // using the mockFirestore to stub Firestore calls and verify interactions.
  });
}
