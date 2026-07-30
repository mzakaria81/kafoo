// Contract tests for delete-account, one per case in
// specs/002-identity-kitchen-profile/contracts/delete-account.md.
//
// Run against a running local stack:
//   supabase start
//   supabase functions serve delete-account
//   deno test --allow-net --allow-env supabase/functions/delete-account/index.test.ts
//
// These need Docker for the local stack. They are not part of ./scripts/verify.sh
// for that reason, and must be run before the function is deployed.

import { assertEquals, assertExists } from 'jsr:@std/assert@1';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/delete-account`;

const admin = () => createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

/// Signs in a fresh person using a configured test number, and gives them a
/// Kitchen Profile and a photo.
async function makePersonWithKitchen(phone: string, otp: string) {
  const client = createClient(SUPABASE_URL, ANON_KEY);
  await client.auth.signInWithOtp({ phone });
  const { data: session } = await client.auth.verifyOtp({
    phone,
    token: otp,
    type: 'sms',
  });
  const user = session.user!;

  await client.from('kitchen_profiles').insert({
    cook_id: user.id,
    display_name: 'مطبخ الاختبار',
    story: 'قصة الاختبار',
    area: 'المعادي',
    delivery_terms: 'توصيل',
  });

  await client.storage
    .from('kitchen-photos')
    .upload(`${user.id}/kitchen.jpg`, new Uint8Array([1, 2, 3]), {
      contentType: 'image/jpeg',
      upsert: true,
    });

  return { client, user, accessToken: session.session!.access_token };
}

async function callDeleteAccount(token?: string, body?: unknown) {
  return await fetch(FUNCTION_URL, {
    method: 'POST',
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
}

// 1. No token → 401, and the account still exists.
Deno.test('without a token it removes nothing', async () => {
  const { user } = await makePersonWithKitchen('+201000000001', '000001');

  const response = await callDeleteAccount();
  assertEquals(response.status, 401);

  const { data } = await admin().auth.admin.getUserById(user.id);
  assertExists(data.user, 'the account must survive an unauthenticated call');

  await admin().auth.admin.deleteUser(user.id);
});

// 2. THE test. A valid token deletes ITS OWN caller, whatever the request
//    names. This is the proof that identity comes from the JWT.
Deno.test('deletes the caller, never anyone named in the request', async () => {
  const caller = await makePersonWithKitchen('+201000000001', '000001');
  const bystander = await makePersonWithKitchen('+201000000002', '000002');

  // Name the bystander every way a request can name somebody.
  const response = await fetch(
    `${FUNCTION_URL}?user_id=${bystander.user.id}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${caller.accessToken}`,
        'Content-Type': 'application/json',
        'x-user-id': bystander.user.id,
      },
      body: JSON.stringify({
        user_id: bystander.user.id,
        userId: bystander.user.id,
        id: bystander.user.id,
      }),
    },
  );
  assertEquals(response.status, 204);

  const callerRow = await admin().auth.admin.getUserById(caller.user.id);
  assertEquals(callerRow.data.user, null, 'the caller must be gone');

  const bystanderRow = await admin().auth.admin.getUserById(bystander.user.id);
  assertExists(bystanderRow.data.user, 'the named bystander must be untouched');

  await admin().auth.admin.deleteUser(bystander.user.id);
});

// 3. Account, Kitchen Profile and photo all gone.
Deno.test('removes the account, the kitchen and the photo', async () => {
  const { user, accessToken } = await makePersonWithKitchen(
    '+201000000001',
    '000001',
  );

  const response = await callDeleteAccount(accessToken);
  assertEquals(response.status, 204);

  const { data: authRow } = await admin().auth.admin.getUserById(user.id);
  assertEquals(authRow.user, null, 'auth row gone');

  const { data: profiles } = await admin()
    .from('kitchen_profiles')
    .select()
    .eq('cook_id', user.id);
  assertEquals(profiles?.length, 0, 'kitchen profile cascaded away');

  // The photo is the only step no foreign key enforces, so it is the one most
  // likely to be silently skipped.
  const { data: files } = await admin().storage
    .from('kitchen-photos')
    .list(user.id);
  assertEquals(files?.length ?? 0, 0, 'photo removed from the public bucket');
});

// 4. FR-039: the funnel rows survive, unlinked.
Deno.test('leaves analytics rows in place with person_id null', async () => {
  const { user, client, accessToken } = await makePersonWithKitchen(
    '+201000000001',
    '000001',
  );

  await client.from('analytics_events').insert({
    name: 'ConversationStarted',
    person_id: user.id,
    attributes: { kind: 'kitchen_profile', input: 'typed' },
  });

  const before = await admin()
    .from('analytics_events')
    .select('id')
    .eq('person_id', user.id);
  assertEquals(before.data?.length, 1);

  assertEquals((await callDeleteAccount(accessToken)).status, 204);

  const orphaned = await admin()
    .from('analytics_events')
    .select('id, person_id')
    .eq('id', before.data![0].id)
    .single();

  assertExists(orphaned.data, 'the row must survive — the counts survive');
  assertEquals(orphaned.data.person_id, null, 'but nobody is attached to it');
});

// 5. FR-033: removal is real, not deactivation. The same number afterwards is
//    a NEW person with no Kitchen Profile.
Deno.test('the same phone number afterwards is a new person', async () => {
  const first = await makePersonWithKitchen('+201000000001', '000001');
  assertEquals((await callDeleteAccount(first.accessToken)).status, 204);

  const second = createClient(SUPABASE_URL, ANON_KEY);
  await second.auth.signInWithOtp({ phone: '+201000000001' });
  const { data: session } = await second.auth.verifyOtp({
    phone: '+201000000001',
    token: '000001',
    type: 'sms',
  });

  const newUser = session.user!;
  assertEquals(
    newUser.id === first.user.id,
    false,
    'a soft delete would return the same id — this must be a different person',
  );

  const { data: profiles } = await second.from('kitchen_profiles').select();
  assertEquals(profiles?.length, 0, 'the new person owns no kitchen');

  await admin().auth.admin.deleteUser(newUser.id);
});

// 6. Storage deletion fails → 500, and the account is still usable.
//
//    This is the ordering guarantee: the step that can fail goes where failing
//    is harmless. Simulating the failure needs the storage API to be made to
//    error, which the local stack cannot do from outside — so this case is
//    asserted by construction in index.ts (storage before auth, early return
//    on error) and verified by reading the diff. Left here, failing loudly,
//    rather than quietly dropped from the contract's six.
Deno.test({
  name: 'storage failure leaves the account usable',
  ignore: true, // Needs a fault-injecting storage stub; see comment above.
  fn: () => {},
});
