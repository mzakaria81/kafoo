-- Stop anonymous enumeration of Cooks via the kitchen-photos bucket.
--
-- 20260730165511 granted SELECT on storage.objects to the `public` role for the whole bucket. A
-- public bucket does not need that to serve images — object URLs bypass policy checks entirely —
-- but it does make the Storage enumeration endpoint answer for anyone holding the publishable key,
-- which ships inside the app. Photos live at `{auth.uid()}/kitchen.jpg`, one folder per Cook, so
-- enumerating the bucket returned the Cook roster and every Cook's account id.
--
-- Measured on preview branch iknhgmnmdecuvsdibrdi, 2026-08-02, with real anonymous requests:
--
--   before   enumerate -> 200, 1 entry: "11111111-2222-3333-4444-555555555555"
--            view      -> 200
--   after    enumerate -> 200, 0 entries
--            view      -> 200
--
-- Replaced rather than simply dropped. The app uploads with upsert, which reads before it writes,
-- and leaving SELECT absent while INSERT, UPDATE and DELETE are all owner-scoped is an asymmetry
-- that invites someone to "fix" it back. An owner-scoped read leaks nothing — it is the same
-- predicate the other three policies already use.

DROP POLICY IF EXISTS "public reads kitchen photos" ON storage.objects;

CREATE POLICY "owner reads own kitchen photo"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'kitchen-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
