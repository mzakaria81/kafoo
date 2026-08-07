/// Whether a Customer has agreed that their words may leave Kafoo. No Flutter,
/// no Supabase.
///
/// **This is not a preference and it is not a setting with a default.** Matching
/// food by meaning requires the sentence a Customer said to be turned into a
/// vector by a model provider outside Kafoo, so the words leave. FR-029a says
/// they must be told before that happens for the first time, and must be able
/// to refuse.
///
/// **There are three states and the third one is the whole point.** [unanswered]
/// is not "off with a nicer name": it is the state in which the question has not
/// been asked, and the question is asked at the **first attempt to search** and
/// never on arrival. Collapsing it to a boolean makes browsing require an answer,
/// which is the one thing FR-029a forbids.
///
/// **Kafoo never stores this.** It lives on the device — see
/// `SearchConsentStore`. Discovery works without an account, so there is nobody
/// to store it against, and a person arriving from a shared link is exactly the
/// person a server-side answer would fail.
library;

/// A Customer's answer to whether their words may leave Kafoo.
enum SearchConsent {
  /// Never asked. Browsing works; the first attempt to search asks.
  unanswered,

  /// Asked and agreed. Search works.
  granted,

  /// Asked and refused. **Search is unavailable, not degraded.**
  ///
  /// A phrase leaves Kafoo in order to become searchable at all — that is the
  /// embedding, not the AI Assistant's judgement — so there is no halfway state
  /// to fall back to. A reduced search matching on spelling is forbidden by name
  /// in `.claude/rules/supabase.md`, and a worse search is not a kindness.
  refused;

  /// Whether a phrase may be sent. The only place this question is answered.
  bool get allowsSearch => this == SearchConsent.granted;

  /// Whether the Customer must be asked before anything can be sent.
  bool get needsAsking => this == SearchConsent.unanswered;
}
