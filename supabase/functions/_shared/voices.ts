/// The two voices the founder chose, by ear, from the twenty-five Egyptian
/// voices in the provider's library, 2026-08-11.
///
/// **Ids live here and nowhere else.** `specs/005-voice-system/plan.md` makes
/// that a constraint rather than a habit: a voice id in application code is a
/// defect, because it is what makes swapping a voice a refactor instead of a
/// one-line change.
///
/// **Moved out of `speak` on 2026-08-14 because a second function needed them.**
/// The live conversation opens with the voice the Cook chose in Settings, and
/// two copies of an id is how a swap ends up half done — one function saying
/// Ghozlan while the other says Ahmad, to the same Cook, in the same minute.
export const VOICES = {
  female: 'xPcC3nehhziQaOrIeAwv',
  male: 'ihycSANIrpHfhWoaq1g3',
} as const;

export type VoiceRole = keyof typeof VOICES;

/// Whether [value] is one of the two roles a caller may ask for.
///
/// **A ROLE, NEVER AN ID.** A client that can name a voice id can name any
/// voice on the account and spend Kafoo's allowance on it.
export function isVoiceRole(value: unknown): value is VoiceRole {
  return value === 'female' || value === 'male';
}
