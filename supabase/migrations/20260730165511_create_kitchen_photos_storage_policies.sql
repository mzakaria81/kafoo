-- Create the kitchen-photos bucket and its RLS policies.
-- Public read is deliberate: FR-019 makes the photo the public face of a Kitchen Profile.
-- No private file may ever be placed in this bucket (see data-model.md).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'kitchen-photos',
  'kitchen-photos',
  true,
  52428800,  -- 50 MiB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "public reads kitchen photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'kitchen-photos');

CREATE POLICY "owner uploads kitchen photo"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'kitchen-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "owner updates kitchen photo"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'kitchen-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "owner deletes kitchen photo"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'kitchen-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
