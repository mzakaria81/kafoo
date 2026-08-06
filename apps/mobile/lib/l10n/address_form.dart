import 'package:flutter/widgets.dart';
import 'package:kafoo_domain/domain.dart';

/// The value an ICU `select` on `addressForm` or `cookForm` switches on.
///
/// The generated localizations take a plain `String` because that is what ICU
/// compares against a branch name, so the enum has to be spelled out somewhere.
/// Doing it here, once, is what stops `'feminine'` being typed by hand at
/// eighty-odd call sites where a typo would silently fall through to the
/// `other` branch and read as masculine.
///
/// Null maps to `other`, which renders masculine. That is not a default chosen
/// for convenience — it is the rule from ADR-0010 that every Cook who predates
/// the question, or who has not reached it yet, still gets a sentence that
/// reads correctly rather than a blank.
String icuAddressForm(AddressForm? form) =>
    form == AddressForm.feminine ? 'feminine' : 'other';

/// Publishes the signed-in person's form of address to the widgets below it.
///
/// An [InheritedWidget] rather than a provider because the value is needed by
/// almost every screen, including the plain [StatelessWidget]s and
/// [StatefulWidget]s that E1 built before any state-management package was in
/// the app. Threading it as a constructor argument would touch every widget in
/// the tree; making every widget a consumer would be the same edit wearing a
/// different hat. This reads through `context`, so a widget that renders a
/// gendered string needs nothing but the context it already has.
///
/// Absent from the tree, [of] answers `other`. A screen shown outside the
/// signed-in surface — sign-in, an error boundary, a widget test that does not
/// care — therefore renders masculine and never crashes for want of a scope.
class AddressFormScope extends InheritedWidget {
  const AddressFormScope({
    required this.form,
    required super.child,
    super.key,
  });

  /// The ICU branch name: `feminine`, or `other` for masculine and unset.
  final String form;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AddressFormScope>()?.form ??
      'other';

  @override
  bool updateShouldNotify(AddressFormScope oldWidget) => oldWidget.form != form;
}

extension AddressFormContext on BuildContext {
  /// The form of address for the person being **addressed** — the reader.
  ///
  /// This is the wrong value for a sentence that *describes* a Cook to somebody
  /// else. Those strings switch on `cookForm` and take the described Cook's
  /// stored form, which has to be passed down from whoever loaded that Cook.
  String get addressForm => AddressFormScope.of(this);
}
