// delete-account — a person removes everything and leaves.
//
// Takes NO arguments. Identity comes from the verified JWT and from nowhere
// else, so this function cannot be made to delete the wrong person however it
// is called, by anyone, ever. That is the design, not an omission — see
// contracts/delete-account.md. Adding a user_id parameter would be the bug.
//
// It exists at all because deleting an auth.users row needs the service role,
// and a service-role key must never reach a phone.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const PHOTO_BUCKET = 'kitchen-photos';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // 1. Verify the token and take the user id from it. Never from anywhere else.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(null, { status: 401, headers: corsHeaders });
  }

  const { data: { user }, error: authError } = await admin.auth.getUser(
    authHeader.slice('Bearer '.length),
  );
  if (authError || !user) {
    return new Response(null, { status: 401, headers: corsHeaders });
  }

  // 2. Delete the storage objects first. Storage has no foreign key, so this
  //    is the one step nothing else will do.
  //
  //    Order matters. If this fails, nothing has been destroyed and the person
  //    retries. Reversed, a failure here would leave orphaned photos in a
  //    public bucket belonging to someone who just asked to be forgotten —
  //    the worst available outcome. The step that can fail goes where failing
  //    is harmless.
  try {
    const { data: files, error: listError } = await admin.storage
      .from(PHOTO_BUCKET)
      .list(user.id);
    if (listError) throw listError;

    if (files && files.length > 0) {
      const { error: removeError } = await admin.storage
        .from(PHOTO_BUCKET)
        .remove(files.map((file) => `${user.id}/${file.name}`));
      if (removeError) throw removeError;
    }
  } catch (_) {
    // The account still exists and is still usable.
    return new Response(null, { status: 500, headers: corsHeaders });
  }

  // 3. Delete the auth.users row. Everything else follows from the foreign
  //    keys in data-model.md: the Kitchen Profile cascades away, and
  //    analytics_events.person_id is set to null while the rows remain.
  //    Duplicating those here would be a second place for the rule to live,
  //    and eventually a second place for it to be wrong.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return new Response(null, { status: 500, headers: corsHeaders });
  }

  // Record that a removal happened, with nobody attached. Recording who asked
  // to be forgotten, inside the function that forgets them, would defeat it.
  await admin.from('analytics_events').insert({
    name: 'AccountRemoved',
    person_id: null,
    attributes: {},
  });

  // 4. Nothing to say, and nobody left to say it to.
  return new Response(null, { status: 204, headers: corsHeaders });
});
