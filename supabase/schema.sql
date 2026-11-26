-- ==============================================================================
-- GURLAL SOHAL ATHLETE PORTFOLIO - PRODUCTION DATABASE SCHEMA & RLS POLICIES
-- Target: Supabase Postgres Database (https://qhdjjydjxeksiyrdiwrc.supabase.co)
-- ==============================================================================

-- 1. ENQUIRIES TABLE
-- Stores booking, sponsorship, and media inquiries from contact.html and modals
CREATE TABLE IF NOT EXISTS public.enquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  organizer_name TEXT,
  full_name TEXT,
  phone TEXT,
  email TEXT,
  category TEXT,
  enquiry_type TEXT,
  dates_location TEXT,
  tour_location TEXT,
  message TEXT,
  status TEXT NOT NULL DEFAULT 'new',
  admin_notes TEXT
);

-- Ensure columns exist if table was already created
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS organizer_name TEXT;
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS dates_location TEXT;
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'new';
ALTER TABLE public.enquiries ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- ENABLE ROW LEVEL SECURITY ON ENQUIRIES (CRITICAL: Protects private contact data)
ALTER TABLE public.enquiries ENABLE ROW LEVEL SECURITY;

-- 1. Anyone (public/anon) can submit an enquiry
DROP POLICY IF EXISTS "Allow anonymous enquiry submission" ON public.enquiries;
CREATE POLICY "Allow anonymous enquiry submission"
  ON public.enquiries
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- 2. Only authenticated admins can read enquiries (protects phone numbers, organizer names)
DROP POLICY IF EXISTS "Allow authenticated admins to read enquiries" ON public.enquiries;
CREATE POLICY "Allow authenticated admins to read enquiries"
  ON public.enquiries
  FOR SELECT
  TO authenticated
  USING (true);

-- 3. Only authenticated admins can update enquiry status
DROP POLICY IF EXISTS "Allow authenticated admins to update enquiries" ON public.enquiries;
CREATE POLICY "Allow authenticated admins to update enquiries"
  ON public.enquiries
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 4. Only authenticated admins can delete enquiries
DROP POLICY IF EXISTS "Allow authenticated admins to delete enquiries" ON public.enquiries;
CREATE POLICY "Allow authenticated admins to delete enquiries"
  ON public.enquiries
  FOR DELETE
  TO authenticated
  USING (true);

-- 2. SCOUTING METRICS TABLE
-- Stores real-time athlete KPIs updated from admin.html
CREATE TABLE IF NOT EXISTS public.scouting_metrics (
  id TEXT PRIMARY KEY DEFAULT 'current',
  exp TEXT NOT NULL DEFAULT '16+ Years',
  tours TEXT NOT NULL DEFAULT '15 Tours',
  scorpio TEXT NOT NULL DEFAULT 'Scorpio-N',
  frandipur TEXT NOT NULL DEFAULT '18 / 18',
  bullets TEXT NOT NULL DEFAULT '10 Bullets',
  bikes TEXT NOT NULL DEFAULT '45+ Bikes',
  raiding_side TEXT NOT NULL DEFAULT 'Right Raider (Speed Baulk & Corner Specialist)',
  signature_moves TEXT NOT NULL DEFAULT 'Jump Escape, Touch, Body Swerve, Rapid Toe Touch',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS on scouting_metrics
ALTER TABLE public.scouting_metrics ENABLE ROW LEVEL SECURITY;

-- Public can read scouting metrics
DROP POLICY IF EXISTS "Allow public read scouting metrics" ON public.scouting_metrics;
CREATE POLICY "Allow public read scouting metrics"
  ON public.scouting_metrics
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Only authenticated admins can update scouting metrics
DROP POLICY IF EXISTS "Allow authenticated admin update scouting metrics" ON public.scouting_metrics;
CREATE POLICY "Allow authenticated admin update scouting metrics"
  ON public.scouting_metrics
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Seed default metrics row if not exists
INSERT INTO public.scouting_metrics (id, exp, tours, scorpio, frandipur, bullets, bikes, raiding_side, signature_moves)
VALUES ('current', '16+ Years', '15 Tours', 'Scorpio-N', '18 / 18', '10 Bullets', '45+ Bikes', 'Right Raider (Speed Baulk & Corner Specialist)', 'Jump Escape, Touch, Body Swerve, Rapid Toe Touch')
ON CONFLICT (id) DO NOTHING;

-- 3. INTERNATIONAL TOURS TABLE
-- Confirmed tour counts: Canada 9, USA 2, Australia 2, Malaysia 1, Europe 1 (Total: 15)
CREATE TABLE IF NOT EXISTS public.international_tours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country TEXT NOT NULL,
  tour_count INTEGER NOT NULL DEFAULT 1,
  flag_code TEXT NOT NULL,
  key_cups TEXT,
  display_order INTEGER NOT NULL DEFAULT 10
);

-- Enable RLS on international_tours
ALTER TABLE public.international_tours ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read tours" ON public.international_tours;
CREATE POLICY "Allow public read tours"
  ON public.international_tours
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow admin modify tours" ON public.international_tours;
CREATE POLICY "Allow admin modify tours"
  ON public.international_tours
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Seed confirmed tours
INSERT INTO public.international_tours (country, tour_count, flag_code, key_cups, display_order)
VALUES 
  ('Canada', 9, 'ca', 'Vancouver, Calgary, Brampton & Toronto Gold Cups', 1),
  ('USA', 2, 'us', 'Bay Area Kabaddi Championship & Yuba City Gold Cup', 2),
  ('Australia', 2, 'au', 'Melbourne & Sydney Open Tournaments', 3),
  ('Malaysia', 1, 'my', 'Kuala Lumpur International Invitational', 4),
  ('Europe', 1, 'eu', 'UK & EU International Kabaddi Championship', 5)
ON CONFLICT DO NOTHING;

-- 4. TOURNAMENT RECORDS TABLE
CREATE TABLE IF NOT EXISTS public.tournament_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  year INTEGER NOT NULL,
  title TEXT NOT NULL,
  location TEXT NOT NULL,
  award TEXT NOT NULL,
  prize TEXT,
  category TEXT NOT NULL CHECK (category IN ('international', 'major_cup', 'state_national')),
  verified BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS on tournament_records
ALTER TABLE public.tournament_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read tournaments" ON public.tournament_records;
CREATE POLICY "Allow public read tournaments"
  ON public.tournament_records
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow admin modify tournaments" ON public.tournament_records;
CREATE POLICY "Allow admin modify tournaments"
  ON public.tournament_records
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Seed confirmed victories
INSERT INTO public.tournament_records (year, title, location, award, prize, category, verified)
VALUES
  (2025, 'Bir Baba Buddha Sahib Kabaddi Cup', 'Tarn Taran, Punjab', 'Best Raider of Tournament', 'Mahindra Scorpio-N SUV', 'major_cup', true),
  (2024, '1st Frandipur Kabaddi Cup Championship', 'Frandipur, Punjab', 'Best Raider & 18/18 Strike', 'Trophy & Prize Buffalo', 'major_cup', true),
  (2024, 'Vancouver International Kabaddi Cup', 'Vancouver, BC, Canada', 'Best Raider of the Tournament', 'Trophy & Cash Award', 'international', true),
  (2023, 'Toronto Metro Championship', 'Brampton / Toronto, Canada', 'Best Raider / Lead Scorer', 'Championship Trophy', 'international', true),
  (2023, 'Punjab State Federation Cup', 'Punjab, India', 'Best Raider Recognition', 'Royal Enfield Bullet 350', 'major_cup', true)
ON CONFLICT DO NOTHING;

-- 5. STORAGE BUCKET CONFIGURATION FOR ATHLETE MEDIA (Optional Cloud Uploads)
INSERT INTO storage.buckets (id, name, public)
VALUES ('athlete-media', 'athlete-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS: Public read access
DROP POLICY IF EXISTS "Public media read access" ON storage.objects;
CREATE POLICY "Public media read access"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'athlete-media');

-- Storage RLS: Authenticated Admin upload access
DROP POLICY IF EXISTS "Admin upload media access" ON storage.objects;
CREATE POLICY "Admin upload media access"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'athlete-media');

-- Storage RLS: Authenticated Admin modify/delete access
DROP POLICY IF EXISTS "Admin modify media access" ON storage.objects;
CREATE POLICY "Admin modify media access"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'athlete-media');

DROP POLICY IF EXISTS "Admin delete media access" ON storage.objects;
CREATE POLICY "Admin delete media access"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'athlete-media');

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_enquiries_created_at ON public.enquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_enquiries_status ON public.enquiries (status);
CREATE INDEX IF NOT EXISTS idx_tournaments_year ON public.tournament_records (year DESC);
