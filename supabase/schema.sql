-- ==============================================================================
-- GURLAL SOHAL ATHLETE PORTFOLIO - PRODUCTION DATABASE SCHEMA & RLS POLICIES
-- Target: Supabase Postgres Database (https://qhdjjydjxeksiyrdiwrc.supabase.co)
-- ==============================================================================

-- 1. ENQUIRIES TABLE
-- Stores booking, sponsorship, and media inquiries from contact.html and modals
CREATE TABLE IF NOT EXISTS public.enquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  organization TEXT,
  enquiry_type TEXT NOT NULL,
  tour_location TEXT,
  estimated_budget TEXT,
  timeline TEXT,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unread' CHECK (status IN ('unread', 'contacted', 'archived', 'spam')),
  admin_notes TEXT
);

-- Enable RLS on enquiries
ALTER TABLE public.enquiries ENABLE ROW LEVEL SECURITY;

-- Enquiries Policies:
-- Anyone (public/anon) can submit an enquiry
DROP POLICY IF EXISTS "Allow anonymous enquiry submission" ON public.enquiries;
CREATE POLICY "Allow anonymous enquiry submission"
  ON public.enquiries
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Only authenticated admins can read, update, or delete enquiries
DROP POLICY IF EXISTS "Allow authenticated admins to read enquiries" ON public.enquiries;
CREATE POLICY "Allow authenticated admins to read enquiries"
  ON public.enquiries
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow authenticated admins to update enquiries" ON public.enquiries;
CREATE POLICY "Allow authenticated admins to update enquiries"
  ON public.enquiries
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

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
  exp TEXT NOT NULL DEFAULT '16+',
  tours TEXT NOT NULL DEFAULT '15',
  scorpio TEXT NOT NULL DEFAULT '1',
  frandipur TEXT NOT NULL DEFAULT '3x',
  bullets TEXT NOT NULL DEFAULT '11',
  bikes TEXT NOT NULL DEFAULT '7',
  raiding_side TEXT NOT NULL DEFAULT 'Right-Corner / All-Rounder',
  signature_moves TEXT NOT NULL DEFAULT 'Thigh Catch, Ankle Hold & Running Hand Touch',
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
VALUES ('current', '16+', '15', '1', '3x', '11', '7', 'Right-Corner / All-Rounder', 'Thigh Catch, Ankle Hold & Running Hand Touch')
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
  (2025, 'Frandipur Kabaddi Cup', 'Frandipur, Punjab', 'Best Stopper (3rd Consecutive)', 'Mahindra Scorpio SUV', 'major_cup', true),
  (2024, 'Frandipur Kabaddi Cup', 'Frandipur, Punjab', 'Best Stopper (2nd Consecutive)', 'Royal Enfield Bullet 350', 'major_cup', true),
  (2023, 'Frandipur Kabaddi Cup', 'Frandipur, Punjab', 'Best Stopper', 'Trophy & Cash Purse', 'major_cup', true),
  (2024, 'Vancouver International Kabaddi Cup', 'Vancouver, BC, Canada', 'Best Stopper of the Tournament', 'Trophy & Cash Award', 'international', true),
  (2023, 'Toronto Metro Championship', 'Brampton / Toronto, Canada', 'Best Defender', 'Trophy', 'international', true)
ON CONFLICT DO NOTHING;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_enquiries_created_at ON public.enquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_enquiries_status ON public.enquiries (status);
CREATE INDEX IF NOT EXISTS idx_tournaments_year ON public.tournament_records (year DESC);
