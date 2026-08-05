// The register detector, tested against sentences a real model actually produced.
//
// `scripts/replay-goldens.ts` needs a live model and a paid-for rate limit, so it runs by hand.
// This does not — it is the one part of that script that can be wrong silently, and it was: the
// version 1 replay reported "Modern Standard markers: none" on a fixture whose `basis` said
// وتعتبر, because the marker test was anchored on a space and the Arabic conjunction is written
// joined to the word after it. A register check that can only say "clean" certifies what it cannot
// see, which is worse than not checking.
//
// Every string below is quoted from docs/ops/eval-meal-analysis.md — what the model wrote on
// 2026-08-03 — or from the Egyptian rewrite of it now in prompts/meal-analysis.md. If the detector
// is ever loosened, these are the sentences it must still catch.

import { assert, assertEquals } from 'jsr:@std/assert@1';
import { findRegisterMarkers } from './replay-goldens.ts';

function msa(text: string): string[] {
  return findRegisterMarkers({ basis: { allergens: text } }).msa;
}

function egyptian(text: string): string[] {
  return findRegisterMarkers({ basis: { allergens: text } }).egyptian;
}

Deno.test('the seven Modern Standard sentences from the version 1 replay are all caught', () => {
  const sentences = [
    'المكرونة تحتوي على جلوتين، والبشاميل والجبنة الرومي يحتويان على ألبان، بالإضافة للبيض المذكور.',
    'هذه الوجبة تعتبر طبقاً رئيسياً مشبعاً.',
    'وجبة مشبعة تعتبر طبق رئيسي',
    'المكرونة تحتوي على دقيق القمح الذي يسبب حساسية الجلوتين',
    'استخدام الرز مع الخضار في المحشي المصري غالباً بيتم تسويته بمرقة بتحتوي على جلوتين.',
    'استخدام المرقة أو التعامل مع المكونات قد يحتوي على آثار جلوتين في الشوربة أو الرز',
    'دي وجبة غداء كاملة ومشبعة وتعتبر طبق رئيسي',
  ];

  for (const sentence of sentences) {
    assert(msa(sentence).length > 0, `reported clean: ${sentence}`);
  }
});

Deno.test('the conjunction prefix does not hide a marker', () => {
  // Both of these went unreported in the version 1 replay. The second one carried the fixture's
  // whole register verdict, which came out as "Modern Standard markers: none".
  assert(msa('الوجبة متكاملة وتعتبر طبق رئيسي').length > 0);
  assert(msa('دي وجبة غداء كاملة ومشبعة وتعتبر طبق رئيسي').length > 0);
});

Deno.test('a register-changing prefix is still not a conjunction', () => {
  // بيحتوي is Egyptian. Making the conjunction optional must not have made every prefix optional,
  // or the detector would flag the dialect it is supposed to be looking for.
  assertEquals(msa('العيش التوست بيحتوي على دقيق القمح اللي فيه جلوتين'), []);
});

Deno.test('the Egyptian rewrites now in the prompt read clean', () => {
  const rewrites = [
    'المكرونة فيها جلوتين، والبشاميل والجبنة الرومي فيهم ألبان، والبيض كمان',
    'دي أكلة بتشبع، يبقى طبق رئيسي',
    'المكرونة معمولة من دقيق قمح، واللي فيه جلوتين',
    'المحشي بيتسوّى في مرقة، والمرقة دي أغلب الوقت فيها جلوتين',
    'المرقة اللي في الشوربة والرز ممكن يبقى فيها جلوتين',
    'دي أكلة غدا كاملة، يبقى طبق رئيسي',
  ];

  for (const sentence of rewrites) {
    assertEquals(msa(sentence), [], `flagged a rewrite: ${sentence}`);
    assert(egyptian(sentence).length > 0, `no Egyptian marker found in: ${sentence}`);
  }
});

Deno.test('the word for Cook is الطباخ, and الكوك is what gets flagged', () => {
  // Backwards until 2026-08-05 — the detector held the pre-ADR-0010 answer and would have flagged
  // every correct reply from the version 2 prompt onward.
  assert(msa('الكوك قال إن فيه حمص').length > 0);
  assertEquals(msa('الطباخ قال إن فيه حمص'), []);
  // And with the conjunction, which is how it appeared in the version 1 replay.
  assert(msa('البقسماط فيه جلوتين، والكوك ذكر البيض').length > 0);
});
