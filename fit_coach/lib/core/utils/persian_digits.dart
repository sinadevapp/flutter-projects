/// Persian (۰-۹) digits for anything shown to the user.
///
/// The UI is Persian, so numbers must be too — this is the single place that
/// decides how a count is rendered.
String fa(Object value) => value.toString().replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(match[0]!)],
    );
