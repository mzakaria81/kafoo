-- Local test harness. Runs on `supabase db reset`; never on `supabase db push`.
--
-- E1's authorization tests call pgTAP (`plan`, `is`, `throws_ok`, `finish`) and four helpers in a
-- `tests` schema. Neither existed anywhere in this repository, so `supabase test db` failed at the
-- first statement — which is part of why those suites had never been seen to run.
--
-- The helpers are vendored rather than pulled from database.dev on purpose: a test harness that
-- needs the network to start is a test harness that fails in CI for reasons unrelated to the code.
--
-- WHERE THIS RUNS. All three cases measured on 2026-08-02, after this comment had been wrong twice
-- in opposite directions:
--
--   Locally                    — yes, on `supabase db reset`.
--   Git-linked preview branch  — yes. Confirmed on branch coamyiukxwrsnvyyextf (pull request #16):
--                                `tests` schema present, pgTAP installed, all four helpers created.
--   Hand-created branch        — no. The `staging` branch got all three migrations and not this
--                                file, because a branch with no repository behind it has nothing to
--                                read the seed from.
--   Production                 — no. `supabase db push` applies migrations only.
--
-- Why it matters: a preview branch is a real, internet-facing Supabase project with its own URL and
-- anon key. This file installs a user-creating helper there, which is what the REVOKE at the foot of
-- the file is for.
--
-- Note for editing this file: Supabase pushes only *new* migration files on each commit to an open
-- pull request. Changing this seed and pushing does not re-run it — close and reopen the pull
-- request, or the branch keeps the previous version.

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS tests;

-- Fixture directory: which test person got which id.
--
-- The suites need a person's id while acting AS that person, and neither anon nor authenticated may
-- read auth.users in any Supabase project — that is one of the reasons the suites had never run.
-- Every id in here was minted by tests.create_supabase_user moments earlier, so exposing it to the
-- test roles reveals nothing they did not just create.
--
-- Deliberately a table and not a SECURITY DEFINER lookup over auth.users. A definer function would
-- answer for *any* address, including a real person's, which is a worse thing to leave lying around
-- than a list of fixtures. This holds only what the harness created.
--
-- No RLS, and that is not a breach of the same-migration rule in CLAUDE.md: this is not a migration
-- and this table never exists in production. seed.sql runs locally and on preview branches only, the
-- `tests` schema is absent from api.schemas so PostgREST does not expose it, and every row is
-- written and rolled back inside a suite's own transaction.
CREATE TABLE IF NOT EXISTS tests.registry (
  email text PRIMARY KEY,
  id    uuid NOT NULL
);

-- Create a person the way Supabase Auth would, so foreign keys to auth.users resolve.
--
-- The argument is the email address, because that is how the suites refer to their fixtures.
-- Named p_email, not email: a PL/pgSQL parameter sharing a name with a column of a table the body
-- writes to makes every mention of it ambiguous, and Postgres rejects the function at run time.
CREATE OR REPLACE FUNCTION tests.create_supabase_user(p_email text)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  uid uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (
    id, instance_id, aud, role, email,
    encrypted_password, email_confirmed_at,
    created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email,
    'not-a-real-password-hash', now(),
    now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    '', '', '', ''
  );

  INSERT INTO tests.registry (email, id) VALUES (p_email, uid)
  ON CONFLICT (email) DO UPDATE SET id = EXCLUDED.id;

  RETURN uid;
END;
$$;

-- Resolve a fixture's id. This is what the suites call instead of reading auth.users.
CREATE OR REPLACE FUNCTION tests.user_id(email text)
RETURNS uuid
LANGUAGE sql
STABLE
AS $$ SELECT r.id FROM tests.registry r WHERE r.email = user_id.email $$;

-- Become that person for the rest of the transaction.
--
-- `set_config(..., true)` is transaction-local, which is what makes the suites' BEGIN/ROLLBACK
-- leave nothing behind. RLS applies from here on, because the role is no longer the owner.
CREATE OR REPLACE FUNCTION tests.authenticate_as(email text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  uid uuid;
BEGIN
  SELECT u.id INTO uid FROM auth.users u WHERE u.email = authenticate_as.email;

  IF uid IS NULL THEN
    RAISE EXCEPTION 'tests.authenticate_as: no user with email %. Call tests.create_supabase_user first.', email;
  END IF;

  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated', 'email', email)::text,
    true
  );
END;
$$;

-- Become a signed-out visitor. auth.uid() returns NULL from here.
CREATE OR REPLACE FUNCTION tests.authenticate_as_anon()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claims', null, true);
END;
$$;

-- Back to the table owner, which bypasses RLS. Always pair this with an authenticate_as —
-- assertions made while still in this state prove nothing about policies.
CREATE OR REPLACE FUNCTION tests.clear_authentication()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', null, true);
END;
$$;

-- Lock down the one helper that writes.
--
-- This file now runs on preview branches, which are reachable from the internet with a published
-- anon key, so "only a test harness would call this" stops being an argument. tests.create_supabase_user
-- inserts straight into auth.users, bypassing sign-up, rate limiting and phone verification.
--
-- Three things already stop an end user reaching it: the `tests` schema is absent from
-- `api.schemas`, so PostgREST does not expose it; the function is SECURITY INVOKER; and neither
-- anon nor authenticated holds INSERT on auth.users. None of those was chosen to defend this
-- function, and any of them could change without anyone connecting the change to this file. Say it
-- directly instead of relying on three accidents.
--
-- Scoped to create_supabase_user ONLY. The other three helpers must stay callable by anon and
-- authenticated: every suite calls tests.clear_authentication() *while* acting as one of those
-- roles, so revoking them here would fail every authorization test in supabase/tests/.
--
-- Verified on branch coamyiukxwrsnvyyextf, 2026-08-02 — its first execution anywhere:
--   create_supabase_user   anon=false authenticated=false
--   authenticate_as        anon=true  authenticated=true
--   authenticate_as_anon   anon=true  authenticated=true
--   clear_authentication   anon=true  authenticated=true
-- and a PostgREST call to the tests schema returns 404.
REVOKE ALL ON FUNCTION tests.create_supabase_user(text) FROM PUBLIC, anon, authenticated;

-- EXECUTE alone is not enough, and reading it as though it were produced a wrong conclusion once.
-- Calling tests.foo() needs USAGE on the schema as well; a new schema grants USAGE to nobody. So
-- the three privileges above read as granted while every call raised "permission denied for schema
-- tests" — which is one of two reasons the suites in supabase/tests/ have never run.
--
-- Safe to grant: the `tests` schema is absent from api.schemas, so PostgREST does not expose it
-- (checked — an RPC call returns 404), and create_supabase_user stays revoked above.
GRANT USAGE ON SCHEMA tests TO anon, authenticated;

-- The fixture directory, for the same reason. Note what is NOT here: no grant on auth.users. The
-- quick way to make these suites run was to give the test roles read access to it, and that would
-- have loosened the exact database the suites exist to check — a green test bought that way proves
-- less than nothing.
GRANT SELECT ON tests.registry TO anon, authenticated;
GRANT EXECUTE ON FUNCTION tests.user_id(text) TO anon, authenticated;

-- >>> GENERATED DEMO DATA — scripts/generate-demo-seed.py — DO NOT EDIT BELOW
--
-- Compiled from supabase/demo-data.json. Edit that file and re-run the generator.
--
-- IT REFUSES TO RUN ON A DATABASE THAT ALREADY HOLDS A PERSON. seed.sql does not execute
-- against production at all — `supabase db push` applies migrations only — and this guard
-- is the second lock rather than the first. business-rules.md calls a synthetic Cook on the
-- real marketplace product-fatal, and 'the tool would not do that' is a weaker sentence than
-- a statement that cannot.
--
-- Every Meal here is seeded WITHOUT a vector, so it is visible in browse and invisible to
-- search until scripts/backfill-meal-embeddings.ts is run against the branch. That is the
-- documented behaviour of a missing embedding, not an oversight: harder to find, never lost.
DO $demo$
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users) THEN
    RAISE NOTICE 'demo data skipped: this database already has a person in it';
    RETURN;
  END IF;

  -- مطبخ التجربة الأول — +201000000001, OTP 000001
  INSERT INTO auth.users (
    id, instance_id, aud, role, phone, phone_confirmed_at,
    encrypted_password, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    phone_change, phone_change_token, email_change_token_current, reauthentication_token
  ) VALUES (
    'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', '+201000000001', now(),
    'not-a-real-password-hash', now(), now(),
    '{"provider":"phone","providers":["phone"]}'::jsonb, '{}'::jsonb,
    '', '', '', '', '', '', '', ''
  );

  INSERT INTO public.kitchen_profiles
    (cook_id, display_name, story, area, delivery_terms, address_form)
  VALUES (
    'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid, 'مطبخ التجربة الأول', 'مطبخ تجريبي مش بتاع حد حقيقي، موجود علشان نجرب كفو.',
    'المهندسين', 'التوصيل اتفاق بين الزبون والطباخ.', 'feminine'
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '86c1c4b6-035d-523f-a85f-2c8108cf64f3'::uuid, 'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid,
    'كشري', 'عدس وأرز ومكرونة وصلصة وتقلية.', 35.00,
    'egyptian', 'main', 'published',
    ARRAY['عدس', 'أرز', 'مكرونة', 'بصل', 'توم', 'صلصة']::text[], ARRAY['جلوتين']::text[],
    620, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'ad31404e-1372-5a13-a2f6-d51b4e5633a0'::uuid, 'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid,
    'ملوخية بالفراخ', 'ملوخية خضرا بتقلية توم، ومعاها فرخة مسلوقة.', 55.00,
    'egyptian', 'main', 'published',
    ARRAY['ملوخية', 'فراخ', 'توم', 'سمنة']::text[], ARRAY['ألبان']::text[],
    480, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '44ba46b0-5dbd-5a81-81c8-b719d73333fe'::uuid, 'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid,
    'محشي كرنب', 'ورق كرنب متلفوف على أرز وشوية خضرة، من غير لحمة خالص.', 45.00,
    'egyptian', 'main', 'published',
    ARRAY['كرنب', 'أرز', 'طماطم', 'بقدونس', 'شبت']::text[], '{}'::text[],
    310, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '27cb39a3-a6fc-5c64-aad0-7ae3c829f10c'::uuid, 'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid,
    'أرز باللبن', 'أرز باللبن بالفرن، وشها محمر.', 25.00,
    'egyptian', 'dessert', 'published',
    ARRAY['أرز', 'لبن', 'سكر']::text[], ARRAY['ألبان']::text[],
    290, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '1b3fca5a-455f-5be9-937c-16ccc548a730'::uuid, 'e864b574-cbc3-526c-b4a4-ca896a1d7423'::uuid,
    'بانيه بالبقسماط', 'شرايح بانيه مقرمشة، ومعاها بطاطس.', 70.00,
    'egyptian', 'main', 'draft',
    ARRAY['فراخ', 'بقسماط', 'بيض']::text[], ARRAY['جلوتين', 'بيض']::text[],
    700, 'ai',
    NULL
  );

  -- مطبخ التجربة التاني — +201000000002, OTP 000002
  INSERT INTO auth.users (
    id, instance_id, aud, role, phone, phone_confirmed_at,
    encrypted_password, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    phone_change, phone_change_token, email_change_token_current, reauthentication_token
  ) VALUES (
    'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', '+201000000002', now(),
    'not-a-real-password-hash', now(), now(),
    '{"provider":"phone","providers":["phone"]}'::jsonb, '{}'::jsonb,
    '', '', '', '', '', '', '', ''
  );

  INSERT INTO public.kitchen_profiles
    (cook_id, display_name, story, area, delivery_terms, address_form)
  VALUES (
    'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid, 'مطبخ التجربة التاني', 'كمان مطبخ تجريبي. مفيش طباخ حقيقي وراه.',
    'الدقي', 'الاستلام من البيت، والتوصيل حسب الاتفاق.', 'masculine'
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'fc75826c-c6f7-5731-b317-829cbb3bb804'::uuid, 'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid,
    'فتة باللحمة', 'عيش محمص وأرز ولحمة ضاني، وصلصة بالتوم والخل.', 90.00,
    'egyptian', 'main', 'published',
    ARRAY['لحمة', 'أرز', 'عيش', 'توم', 'خل']::text[], ARRAY['جلوتين']::text[],
    830, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'af7b3a5e-ac5c-5337-af41-39e2f264ed86'::uuid, 'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid,
    'سمك بلطي مشوي', 'بلطي مشوي على الفحم، ومعاه أرز صيادية.', 110.00,
    'egyptian', 'main', 'published',
    ARRAY['سمك', 'أرز', 'ليمون', 'كمون']::text[], ARRAY['سمك']::text[],
    540, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'e6cee2dc-69fb-58e9-ba25-f2808006e92b'::uuid, 'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid,
    'طعمية', 'طعمية مقلية بالسمسم، ومعاها طحينة.', 20.00,
    'egyptian', 'starter', 'published',
    ARRAY['فول', 'كزبرة', 'سمسم', 'طحينة']::text[], ARRAY['سمسم']::text[],
    350, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '5051ee73-79dd-5b86-8b4f-0db490b79d66'::uuid, 'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid,
    'سلطة زبادي بالخيار', 'زبادي بالخيار والنعناع، تنفع جنب أي أكلة.', 15.00,
    'egyptian', 'side', 'published',
    ARRAY['زبادي', 'خيار', 'نعناع', 'توم']::text[], ARRAY['ألبان']::text[],
    120, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '89558fe4-d8a6-5275-a9f2-96d826d296b1'::uuid, 'de2d8a34-7ff1-51e5-9f86-944140049b18'::uuid,
    'كبيبة مقلية', 'كبيبة برغل محشية لحمة مفرومة وصنوبر.', 65.00,
    'levantine', 'starter', 'unavailable',
    ARRAY['برغل', 'لحمة مفرومة', 'صنوبر', 'بصل']::text[], ARRAY['جلوتين', 'مكسرات']::text[],
    610, 'ai',
    NULL
  );

  -- مطبخ التجربة التالت — +201000000003, OTP 000003
  INSERT INTO auth.users (
    id, instance_id, aud, role, phone, phone_confirmed_at,
    encrypted_password, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    phone_change, phone_change_token, email_change_token_current, reauthentication_token
  ) VALUES (
    '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', '+201000000003', now(),
    'not-a-real-password-hash', now(), now(),
    '{"provider":"phone","providers":["phone"]}'::jsonb, '{}'::jsonb,
    '', '', '', '', '', '', '', ''
  );

  INSERT INTO public.kitchen_profiles
    (cook_id, display_name, story, area, delivery_terms, address_form)
  VALUES (
    '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid, 'مطبخ التجربة التالت', 'المطبخ ده موجود علشان نشوف الأكل في منطقة تالتة.',
    'مصر الجديدة', 'التوصيل للمنطقة القريبة بس، بالاتفاق.', 'feminine'
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'fceace85-1127-5221-891c-7391cd92678c'::uuid, '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid,
    'برجر لحمة', 'برجر لحمة بلدي في عيش بريوش، ومعاه بطاطس.', 85.00,
    'international', 'main', 'published',
    ARRAY['لحمة', 'عيش', 'جبنة', 'طماطم']::text[], ARRAY['جلوتين', 'ألبان']::text[],
    780, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'd0ff1a24-8a7f-5e53-abf1-9aaf3b597411'::uuid, '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid,
    'مكرونة بشاميل', 'مكرونة بلحمة مفرومة وبشاميل، متحمرة في الفرن.', 60.00,
    'egyptian', 'main', 'published',
    ARRAY['مكرونة', 'لحمة مفرومة', 'لبن', 'زبدة', 'جوزة الطيب']::text[], ARRAY['جلوتين', 'ألبان']::text[],
    720, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'b4024c82-75f9-5a15-8606-f9ee8e77b379'::uuid, '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid,
    'شوربة عدس', 'شوربة عدس أصفر بالكمون، سخنة وخفيفة.', 22.00,
    'egyptian', 'starter', 'published',
    ARRAY['عدس', 'جزر', 'بصل', 'كمون']::text[], '{}'::text[],
    210, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    'a5234eb5-e4d7-5ef1-b029-9a8fd0ca4564'::uuid, '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid,
    'بسبوسة بالقشطة', 'بسبوسة بالسميد والقشطة، مغرقة في الشربات.', 30.00,
    'egyptian', 'dessert', 'published',
    ARRAY['سميد', 'قشطة', 'سكر', 'جوز الهند']::text[], ARRAY['ألبان', 'جلوتين']::text[],
    450, 'ai',
    now()
  );

  INSERT INTO public.meals
    (id, cook_id, title, description, price, cuisine, category, status,
     ingredients, allergens, calories, nutrition_source, published_at)
  VALUES (
    '6f5d8f3c-60be-5b69-b948-c1780fcfdc04'::uuid, '43568172-6b91-536d-8a07-6d9fe65d9c17'::uuid,
    'سلطة بلدي', 'طماطم وخيار وبصل وجرجير، بزيت زيتون وليمون.', 18.00,
    'egyptian', 'side', 'published',
    '{}'::text[], '{}'::text[],
    90, 'ai',
    now()
  );

  RAISE NOTICE 'demo data loaded: 3 cooks';
END
$demo$;
-- <<< END GENERATED DEMO DATA
