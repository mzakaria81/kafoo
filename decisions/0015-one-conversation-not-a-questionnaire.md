# ADR-0015 — One conversation, not a questionnaire

**Status:** Accepted
**Date:** 2026-08-13
**Decider:** Founder
**Amends:** ADR-0013 (voice-first). The voice decision stands; what changes is the *shape* of the
exchange the voice carries.
**Supersedes:** the fixed step sequences in `packages/domain/lib/meal_step.dart` and
`packages/domain/lib/conversation_step.dart` as *scripts*. They survive as *checklists* — see
"What the state machine becomes".

## Context

Kafoo says "conversation first" and has never built one. What it built is a form read aloud.

`meal_step.dart` holds four questions — dish, description, photo, price — and
`MealConversationController.currentStep` returns "the next unanswered step". `conversation_step.dart`
does the same for Kitchen Profile onboarding, in five. `.claude/rules/ai.md` states the rule that
produced this: **"One question at a time."** Each answer is written, the next question is asked, and
when the questions run out a summary appears with estimates to approve. Every screen in that flow is
a screen because a step ended.

That is a wizard. It collects, and it does nothing else. A Cook cannot ask it anything, cannot
change her mind about something two questions back without the flow noticing, and gets no benefit
from having used Kafoo before — the fifth Meal is asked the same four questions as the first.

On 2026-08-13 the founder rejected this shape:

> I prefer the conversation to be more fluent. Not a series of static questions to get some
> information from the Cook or the Customer and that's it. I like it as if the Customer/Cook are
> having an open conversation with our app, and within that conversation the app collects the
> needed info — but also they can ask questions, ask for advice, «what do you propose to cook»,
> «what would you like to eat».

This is a product decision, and it is the right one for a specific reason: **an interrogation is
not how anyone earns a Cook's trust.** The person Kafoo exists for is being asked to hand her
livelihood to an app. A machine that only takes, in a fixed order, teaches her she is filling in a
form. A machine that also answers, remembers, and suggests is a colleague.

## Decision

**The assistant holds one open conversation per journey. Information is collected inside it, never
demanded by it.**

Six rules, binding:

1. **One screen per journey, not one screen per question.** Publishing a Meal is one conversation
   screen. Onboarding a new Cook is one conversation screen. The consecutive screens they replace
   become nothing — not hidden, deleted.

2. **The assistant chooses what to say; Kafoo decides what is still missing.** Kafoo owns the list
   of facts a Meal needs. It hands that list to the model each turn and the model decides whether to
   ask for one, ask for two, answer a question first, or say nothing and let the Cook keep talking.
   **Kafoo never orders the questions and the model never decides what a Meal requires.**

3. **The Cook or Customer may steer, and the assistant follows.** «إيه اللي تنفع أطبخه بكرة؟» in the
   middle of publishing a Meal is a normal turn, not an error. The assistant answers it, then
   returns to what was unfinished — out loud, so the return is not a surprise.

4. **Nothing is asked that was already said, in this conversation or an earlier one.** Repeating a
   question a person has already answered is the defect this ADR exists to remove. Memory across
   conversations is ADR-0016 and is a separate decision; within one conversation the rule binds
   today.

5. **Advice is advice, and it never becomes a stored fact.** «أنا أقترح المحشي، بيتباع كويس في
   الشتا» is a suggestion. If the Cook acts on it, the Meal is created from what *she* then says.
   A suggestion the assistant made must never arrive in the database as though she said it.

6. **Everything ADR-0013 made binding still binds, unchanged.** The confirmation gate before an
   irreversible action. «أيوة» by voice or tap, and silence never confirming. The paraphrase rather
   than the transcript. The closed set of eleven glance words. Numerals as the largest type. Tap as
   a complete alternative. **A conversation that is pleasant to have is not a reason to weaken any
   of them** — it is the reason they get used more.

### What the state machine becomes

ADR-0009 recorded, correctly, that the conversation is a finite-state machine Kafoo owns and the
model does not. **That stays true and its job changes.**

| Before | After |
|---|---|
| An ordered sequence of steps | An unordered set of required facts |
| `currentStep` returns the next question to ask | `stillMissing` returns what is not known yet |
| A step is a screen | Nothing is a screen |
| The model is told which slot to fill | The model is told which slots are empty and picks |
| Completion = last step answered | Completion = no required fact missing |

The domain rule "a Meal needs a name, a description, a price, a cuisine and a category before it can
leave draft" is unchanged and still enforced by the database. What is deleted is the claim that
those five must be collected in a fixed order, one screen at a time.

### The AI write boundary, restated because this is where it would break

An open conversation makes the model an active participant, so the rule it must not cross is worth
writing out again rather than referring to:

> **The assistant may write, to a draft, only what the person said.** A price the Cook spoke goes in.
> A calorie estimate, an inferred cuisine, a suggested category and a guessed allergen list do not —
> those are AI-derived, and every one of them still passes an explicit human approval step before it
> reaches the database. Publishing is read back in full and waits for «أيوة».

This is `.claude/rules/business-rules.md` unchanged. It reads differently in a fluent conversation
than in a wizard, because in a wizard the approval step was a screen and here it is a sentence the
assistant says out loud — but it is the same step and it is not optional.

**A conversational surface is also a prompt-injection surface**, and it is now a much wider one: a
Cook's Meal description was already untrusted input, and now so is everything anyone says for as
long as they keep talking. Nothing a person says may change what the assistant is permitted to do.

## What this costs

**Every screen in the Meal and Kitchen Profile flows is rework, and some of it is deletion.**
`meal_conversation.dart` (499 lines), `meal_conversation_controller.dart` (637 lines),
`kitchen_profile/presentation/conversation.dart` (378 lines), the summary, the fallback questions and
the estimate rows were all written against "the next unanswered step". They do not evolve into this;
they are replaced by something smaller.

**Quality stops being checkable by a fixed test.** A four-question wizard is easy to test — there are
four paths. An open conversation has no enumerable paths, so the tests move from "does step 3 follow
step 2" to "does a published Meal ever contain a fact nobody said" and "can anything a person types
make the assistant publish". That is a harder kind of test and a better one.

**It needs a real-time voice path Kafoo does not have.** Turn-by-turn request/response is tolerable
for a wizard and not for a conversation: a Cook who has to wait two seconds after every sentence
stops talking. That is ADR-0017, and this decision depends on it.

**It costs more per conversation, in money.** A wizard makes one model call per Meal. A conversation
makes one per turn, plus speech in both directions for the whole exchange. The founder has accepted
this explicitly for the current phase — there are no real Cooks yet and the subscription can be spent
freely — but it becomes a per-Meal unit cost the day there are.

## Options considered

| Option | Why not |
|---|---|
| Keep the wizard, make the copy warmer | The complaint is not tone. A friendlier form is still a form, and it still cannot answer «إيه اللي أطبخه؟» |
| Free conversation with the model owning the requirements too | The model would decide when a Meal is complete. It would be wrong occasionally and silently, and the database rule and the conversation would drift apart. Kafoo keeps the checklist |
| Conversation for the Cook, wizard for the Customer | Rejected for the same reason ADR-0013 rejected split surfaces: two products, one design system, and often the same person |
| Do it after Orders (E4) | The founder's direction is that this *is* the MVP journey. Building the wizard further and replacing it later spends the same money twice |

## Consequences

- `docs/design/DESIGN.md` gains §11, the conversation screen. It is assembled almost entirely from
  components §6 and §10 already define; the one genuinely new thing is the **receipt panel** — what
  is known so far, in numerals and glance words, updating as the person talks.
- `.claude/rules/ai.md`'s "One question at a time" is rewritten. It was a correct rule against
  interviews and it became the instruction that built one.
- `packages/domain/`'s two step files lose their ordering and keep their requirements.
- The five-Cook checkpoint in CLAUDE.md is now a test of *this*: a Cook speaks a Meal into being in
  one conversation, hears it read back, says «أيوة», and it is published.

**What is not decided here.** How the live conversation reaches a model (ADR-0017) and whether
Kafoo remembers anything between conversations (ADR-0016). Both are separable and both are written
down separately on purpose.
