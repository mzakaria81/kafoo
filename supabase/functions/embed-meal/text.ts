// What a Meal is represented by, kept out of index.ts so a test can import it.
//
// `Deno.serve` runs at module load, so importing the handler starts a server — a test that wanted
// this one function would have to open a port and get `NotCapable: Requires net access` instead of
// an assertion. Splitting it is also the honest boundary: this is the decision about what a Meal
// MEANS, and the handler is plumbing around it.

/// The text a Meal is represented by.
///
/// Title and description only. Deliberately NOT price, status or timestamps: a Meal whose price
/// changed is the same food, and including it would make an edit that changes nothing about the
/// dish spend a model call and shift its ranking.
///
/// **It takes a row, not a request.** There is no parameter through which a caller's words can
/// arrive, which is what makes ranking manipulation impossible here rather than merely forbidden.
export function embeddableText(meal: { title: string; description: string | null }): string {
  return [meal.title, meal.description ?? ''].join('\n').trim();
}
