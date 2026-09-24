import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/widgets/student_avatar.dart';
import 'package:fit_coach/features/coach_hub/presentation/add_student_screen.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:fit_coach/features/coach_hub/presentation/edit_student_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// A real 1×1 PNG.
///
/// The avatar decodes stored bytes through `MemoryImage`, so they have to
/// *be* an image: invented bytes make the image service throw
/// "Invalid image data" and fail the test for a reason unrelated to whatever
/// it was meant to check.
Uint8List bytes() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// Seeds one private and one public student.
  Future<void> seedRoster() async {
    await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final public = await db.insertUser(
      UsersCompanion.insert(
        name: 'رضا',
        role: UserRole.student,
        visibility: Value(StudentVisibility.public),
      ),
    );
    await db.updateStudentPhoto(public, bytes());
  }

  group('the three tabs', () {
    testWidgets('all three exist, with "all" selected first', (tester) async {
      await seedRoster();
      await pump(tester, const CoachHubScreen());

      expect(find.text('همه'), findsOneWidget);
      expect(find.text('خصوصی'), findsOneWidget);
      expect(find.text('عمومی'), findsOneWidget);
      // The default is the view the screen had before tabs existed, so nobody
      // arrives looking at a shorter list than they had.
      expect(find.text('علی'), findsOneWidget);
      expect(find.text('رضا'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('the private tab hides public students', (tester) async {
      await seedRoster();
      await pump(tester, const CoachHubScreen());

      await tester.tap(find.text('خصوصی'));
      await tester.pumpAndSettle();

      expect(find.text('علی'), findsOneWidget);
      expect(find.text('رضا'), findsNothing);

      await unmount(tester);
    });

    testWidgets('the public tab hides private students', (tester) async {
      await seedRoster();
      await pump(tester, const CoachHubScreen());

      await tester.tap(find.text('عمومی'));
      await tester.pumpAndSettle();

      expect(find.text('رضا'), findsOneWidget);
      expect(find.text('علی'), findsNothing);

      await unmount(tester);
    });

    testWidgets('a tab with nobody in it says so rather than looking broken',
        (tester) async {
      await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await pump(tester, const CoachHubScreen());

      await tester.tap(find.text('عمومی'));
      await tester.pumpAndSettle();

      // Not an error state: the students are simply under another tab.
      expect(find.text('شاگرد گروهی‌ای ثبت نشده'), findsOneWidget);
      expect(find.text('شاگردان این دسته در تب دیگری هستند'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('an empty roster offers to add a student, in every tab',
        (tester) async {
      await pump(tester, const CoachHubScreen());

      // Every tab explains an empty roster rather than showing a blank list.
      for (final tab in ['همه', 'خصوصی', 'عمومی']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text('هنوز شاگردی ثبت نشده'), findsOneWidget,
            reason: 'tab $tab');
      }

      // And the offered action actually works — asserted by tapping rather
      // than by widget type, because `FilledButton.icon()` renders as a
      // private `_FilledButtonWithIcon`, which no public finder matches.
      await tester.tap(find.text('افزودن شاگرد'));
      await tester.pumpAndSettle();
      expect(find.byType(AddStudentScreen), findsOneWidget);

      await unmount(tester);
    });
  });

  group('the student row', () {
    testWidgets('shows a default icon when there is no photo', (tester) async {
      final id = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await pump(tester, const CoachHubScreen());

      final student = await db.getUser(id);
      expect(student.photo, isNull);
      // The row uses the shared avatar, so the person icon is what renders.
      expect(find.byIcon(Icons.person), findsWidgets);

      await unmount(tester);
    });

    testWidgets('shows the coach\'s photo when there is one', (tester) async {
      final id = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await db.updateStudentPhoto(id, bytes());
      await pump(tester, const CoachHubScreen());

      final avatars = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .toList();
      expect(avatars, isNotEmpty);
      // The stored bytes become a real image provider, not just a colour.
      expect(avatars.any((a) => a.backgroundImage is MemoryImage), isTrue);
      // A set photo means the placeholder icon goes away.
      expect(find.byIcon(Icons.person), findsNothing);

      await unmount(tester);
    });

    testWidgets('states the student\'s type under their name', (tester) async {
      await seedRoster();
      await pump(tester, const CoachHubScreen());

      // The tab is a filter; the row restates the fact for a quick glance.
      expect(find.text('شاگرد خصوصی'), findsOneWidget);
      expect(find.text('شاگرد گروهی'), findsOneWidget);

      await unmount(tester);
    });
  });

  group('adding a student', () {
    testWidgets('defaults to private and shows the placeholder photo',
        (tester) async {
      await pump(tester, const AddStudentScreen());

      // The default icon, because no photo has been chosen yet.
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      // "Private" is the selected segment without the coach touching anything.
      final segmented = tester.widget<SegmentedButton<StudentVisibility>>(
        find.byType(SegmentedButton<StudentVisibility>),
      );
      expect(segmented.selected, {StudentVisibility.private});

      await unmount(tester);
    });

    testWidgets('a student added as public lands in the public tab',
        (tester) async {
      await pump(tester, const AddStudentScreen());

      await tester.enterText(find.byType(TextField), 'رضا');
      await tester.tap(find.text('شاگرد گروهی'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      final students = await db.getAllUsers();
      expect(students.single.name, 'رضا');
      expect(students.single.visibility, StudentVisibility.public);
      // And the form returned to the list, as it always did.
      expect(find.byType(AddStudentScreen), findsNothing);

      await unmount(tester);
    });

    testWidgets('a student added with no photo is accepted', (tester) async {
      await pump(tester, const AddStudentScreen());

      await tester.enterText(find.byType(TextField), 'سینا');
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      final student = (await db.getAllUsers()).single;
      expect(student.name, 'سینا');
      expect(student.photo, isNull);
      expect(student.visibility, StudentVisibility.private);

      await unmount(tester);
    });

    testWidgets('an empty name is still rejected', (tester) async {
      await pump(tester, const AddStudentScreen());

      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('نام را وارد کنید'), findsOneWidget);
      expect(await db.getAllUsers(), isEmpty);

      await unmount(tester);
    });
  });

  group('editing a student', () {
    testWidgets('starts from the student\'s current values', (tester) async {
      final id = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await db.updateStudentPhoto(id, bytes());
      await db.updateStudentVisibility(id, StudentVisibility.public);

      final student = await db.getUser(id);
      await pump(tester, EditStudentScreen(student: student));

      expect(find.text('علی'), findsOneWidget);

      final segmented = tester.widget<SegmentedButton<StudentVisibility>>(
        find.byType(SegmentedButton<StudentVisibility>),
      );
      expect(segmented.selected, {StudentVisibility.public});

      // A photo is present, so "change" is offered instead of "add".
      expect(find.text('تغییر عکس'), findsOneWidget);
      expect(find.text('حذف عکس'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('clearing the photo falls back to the default icon',
        (tester) async {
      final id = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await db.updateStudentPhoto(id, bytes());

      await pump(tester, EditStudentScreen(student: await db.getUser(id)));
      expect(find.byIcon(Icons.person), findsNothing);

      await tester.tap(find.text('حذف عکس'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      expect((await db.getUser(id)).photo, isNull);

      await unmount(tester);
    });

    testWidgets('saves the name and the type together', (tester) async {
      final id = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await pump(tester, EditStudentScreen(student: await db.getUser(id)));

      await tester.enterText(find.byType(TextField), 'علی رضایی');
      await tester.tap(find.text('شاگرد گروهی'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      final saved = await db.getUser(id);
      expect(saved.name, 'علی رضایی');
      expect(saved.visibility, StudentVisibility.public);

      await unmount(tester);
    });

    testWidgets('an empty name is rejected and nothing is saved',
        (tester) async {
      final id = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await pump(tester, EditStudentScreen(student: await db.getUser(id)));

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('نام را وارد کنید'), findsOneWidget);
      expect((await db.getUser(id)).name, 'علی');
      expect(find.byType(EditStudentScreen), findsOneWidget);

      await unmount(tester);
    });
  });

  group('the shared avatar', () {
    testWidgets('renders the person icon with no photo', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Center(
            child: StudentAvatar(
              student: User(
                id: 1,
                name: 'علی',
                role: UserRole.student,
                photo: null,
                visibility: StudentVisibility.private,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('renders an image with a photo', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Center(
            child: StudentAvatar(
              student: User(
                id: 1,
                name: 'علی',
                role: UserRole.student,
                photo: bytes(),
                visibility: StudentVisibility.private,
              ),
            ),
          ),
        ),
      );

      // A photo replaces the placeholder — the two must not both show.
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);

      await unmount(tester);
    });
  });

  group('deleting a student', () {
    /// Brings [finder] into view, and therefore into the tree.
    ///
    /// The edit form scrolls, so its delete button sits below the fold and
    /// does not exist until scrolled to — the same scroll the coach does.
    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    /// Walks to the edit screen exactly as the coach would.
    Future<void> openEdit(WidgetTester tester, String name) async {
      await pump(tester, const CoachHubScreen());
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.byTooltip('ویرایش شاگرد'), findsOneWidget);

      await tester.tap(find.byTooltip('ویرایش شاگرد'));
      await tester.pumpAndSettle();
      // Reached, or everything below fails with a confusing "No element"
      // from a scroll that has nothing to scroll.
      expect(find.byType(EditStudentScreen), findsOneWidget);
    }

    testWidgets('cancelling the confirmation keeps the student', (tester) async {
      await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await openEdit(tester, 'علی');

      final remove = find.text('حذف شاگرد');
      await scrollTo(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();

      // The confirmation names them, so nobody deletes the wrong record.
      expect(find.textContaining('علی'), findsWidgets);

      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();

      expect((await db.getAllUsers()).map((u) => u.name).toList(), ['علی']);
      expect(find.byType(EditStudentScreen), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('confirming removes them and returns to the roster', (
      tester,
    ) async {
      await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      await db.insertUser(
        UsersCompanion.insert(name: 'رضا', role: UserRole.student),
      );
      await openEdit(tester, 'علی');

      final remove = find.text('حذف شاگرد');
      await scrollTo(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
      await tester.pumpAndSettle();

      expect((await db.getAllUsers()).map((u) => u.name).toList(), ['رضا']);
      // Not the edit screen, and not the deleted student's page either: the
      // coach is back at the roster, and it already reflects the removal.
      expect(find.byType(EditStudentScreen), findsNothing);
      expect(find.text('رضا'), findsOneWidget);
      expect(find.text('علی'), findsNothing);

      await unmount(tester);
    });
  });
}
