# Contract — `discover` Edge Function

Turns a phrase into ranked Meals. **On the critical path.** Holds no service-role key and writes
nothing.

## Shape

**Request**: the phrase as the Customer said it, an optional area, and the caller's own credentials.

**Response**: ranked Meals the caller is permitted to see, plus what Kafoo understood — which
exclusions it found, and whether it found a negation it could not parse.

**The response never contains a judgement.** That is `judge-results`, and separating them is what
makes FR-011 true by construction rather than by discipline.

## What it does, in order

1. Parse the phrase deterministically: negation markers, the nouns after them, an area. **No model
   call.** `research.md` §3 — a generative call here would put the model on the critical path, which
   FR-011 and the 2026-08-06 latency ruling both forbid.
2. Embed the phrase through the provider registry, typed as a query rather than a document.
3. Normalise the vector. At 768 dimensions the provider does not, and cosine similarity on a
   non-unit vector is quietly wrong.
4. Call `search_meals` **as the caller**, passing the caller's credentials through. Not with a
   service-role key, and not with the function's own identity.
5. Return what came back, unfiltered and unreordered.

## Rules this function must not break

- **It never uses a service-role key.** It is reachable by anyone, signed in or not.
- **It never writes.** Not a log of the phrase, not a cache keyed on the phrase, not an analytics
  attribute containing it. FR-029 and SC-011. A cache keyed on the phrase is the subtle one: it is
  a recording, however it is described.
- **It never reorders what the database returned.** Ranking is `search_meals`' job. A second sort
  here is a second ranking rule in a second place.
- **It never widens an area.** FR-024a — widening is the Customer's action. If the named area is
  empty, this function returns empty and says which areas are not.

## Failure behaviour

| Failure | Response |
|---|---|
| The embedding provider is unreachable or slow | Kafoo says search is unavailable **and browsing still works**. Search failing must not take browsing with it. |
| A negation marker was found but its noun did not map | Return results **and** the unparsed marker, so the interface can say Kafoo did not understand the exclusion. **Never** return results as though no exclusion was asked for. |
| The area named matches nothing any Cook wrote | Empty results plus the areas that do have food. Not a silent widening, not an error. |
| `search_meals` returns nothing | Empty results. Not an error — this is an ordinary outcome and `judge-results` decides what to say about it. |

**The second row is the one that matters.** A dropped exclusion is indistinguishable from no
exclusion in the response, and the Customer sees meat they asked not to see. This must have a test
that has been seen to fail.

## Measurement

`SearchPerformed` with `result_count`. **Never the phrase**, in the event, in a log line, or in an
error carrying the request that produced it.
