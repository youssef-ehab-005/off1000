-- Add image column to categories
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS image text;

-- Storage policies for category-images bucket
-- Anyone can read (needed for signed URL creation / display)
CREATE POLICY "Public read category images"
ON storage.objects FOR SELECT
USING (bucket_id = 'category-images');

-- Authenticated users can upload category images
CREATE POLICY "Authenticated upload category images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'category-images');

-- Authenticated users can update category images
CREATE POLICY "Authenticated update category images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'category-images');

-- Authenticated users can delete category images
CREATE POLICY "Authenticated delete category images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'category-images');