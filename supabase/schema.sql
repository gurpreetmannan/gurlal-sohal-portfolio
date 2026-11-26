-- ==============================================================================
-- GURLAL SOHAL ATHLETE PORTFOLIO - PRODUCTION DATABASE SCHEMA & RLS POLICIES
-- Target: Supabase Postgres Database (https://qhdjjydjxeksiyrdiwrc.supabase.co)
-- Security Standard: Multi-Role Administrator Authorization (auth.users + admin_users)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ADMINISTRATOR AUTHORIZATION TABLE (Role-Based Access Control)
-- ------------------------------------------------------------------------------
-- Dedicated admin table linked to auth.users. Only registered UUIDs have admin rights.
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'superadmin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  notes TEXT
);

-- Enable RLS on admin_users
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies on admin_users
DROP POLICY IF EXISTS "Admins can view own admin record" ON public.admin_users;
DROP POLICY IF EXISTS "Public cannot access admin users" ON public.admin_users;

-- Authenticated users can ONLY verify their own administrator status
CREATE POLICY "Admins can view own admin record"
  ON public.admin_users
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Explicitly revoke all public / anonymous privileges on admin_users
REVOKE ALL ON public.admin_users FROM anon, authenticated;
GRANT SELECT ON public.admin_users TO authenticated;
-- Notice: INSERT, UPDATE, DELETE are NOT granted to authenticated or anon.
-- Only the database owner via trusted SQL Editor or service_role can add/remove administrators.

-- ------------------------------------------------------------------------------
-- 2. SECURITY DEFINER AUTHORIZATION FUNCTION: is_admin()
-- ------------------------------------------------------------------------------
-- Secure function to check whether the current authenticated caller is an administrator.
-- Fixed search_path prevents search_path poisoning attacks.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = auth.uid()
  );
END;
$$;

-- Grant execution to authenticated users and anon (needed for policy evaluation)
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- ------------------------------------------------------------------------------
-- 3. ENQUIRIES TABLE (Public Insert, Strictly Admin-Only Read/Update/Delete)
-- ------------------------------------------------------------------------------
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

-- ENABLE ROW LEVEL SECURITY
ALTER TABLE public.enquiries ENABLE ROW LEVEL SECURITY;

-- Drop all legacy or conflicting policies (avoids PostgreSQL OR-combination leaks)
DROP POLICY IF EXISTS "Allow anonymous enquiry submission" ON public.enquiries;
DROP POLICY IF EXISTS "Allow public insert enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Allow authenticated admins to read enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Allow authenticated admins to update enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Allow authenticated admins to delete enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.enquiries;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.enquiries;
DROP POLICY IF EXISTS "Enable update for all users" ON public.enquiries;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.enquiries;
DROP POLICY IF EXISTS "Public can view enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Users can view enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Allow admin read enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Allow admin update enquiries" ON public.enquiries;
DROP POLICY IF EXISTS "Allow admin delete enquiries" ON public.enquiries;

-- Policy 3.1: Anonymous and authenticated visitors can INSERT booking enquiries with validation
CREATE POLICY "Allow public insert enquiries"
  ON public.enquiries
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    length(trim(coalesce(organizer_name, ''))) >= 2
    AND length(trim(coalesce(phone, ''))) >= 5
    AND length(coalesce(message, '')) <= 5000
  );

-- Policy 3.2: ONLY verified administrators can SELECT private enquiries
CREATE POLICY "Allow admin read enquiries"
  ON public.enquiries
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- Policy 3.3: ONLY verified administrators can UPDATE enquiry status and notes
CREATE POLICY "Allow admin update enquiries"
  ON public.enquiries
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Policy 3.4: ONLY verified administrators can DELETE enquiries
CREATE POLICY "Allow admin delete enquiries"
  ON public.enquiries
  FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- Database Grants on enquiries
REVOKE ALL ON public.enquiries FROM anon, authenticated;
GRANT INSERT ON public.enquiries TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.enquiries TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. SCOUTING METRICS TABLE (Public Read, Administrator-Only Write)
-- ------------------------------------------------------------------------------
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

ALTER TABLE public.scouting_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read scouting metrics" ON public.scouting_metrics;
DROP POLICY IF EXISTS "Allow authenticated admin update scouting metrics" ON public.scouting_metrics;
DROP POLICY IF EXISTS "Allow admin modify scouting metrics" ON public.scouting_metrics;

-- Public read for athlete portfolio display
CREATE POLICY "Allow public read scouting metrics"
  ON public.scouting_metrics
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- ONLY verified administrators can modify scouting metrics
CREATE POLICY "Allow admin modify scouting metrics"
  ON public.scouting_metrics
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

REVOKE ALL ON public.scouting_metrics FROM anon, authenticated;
GRANT SELECT ON public.scouting_metrics TO anon, authenticated;
GRANT UPDATE, INSERT, DELETE ON public.scouting_metrics TO authenticated;

-- Seed default metrics row if not exists
INSERT INTO public.scouting_metrics (id, exp, tours, scorpio, frandipur, bullets, bikes, raiding_side, signature_moves)
VALUES ('current', '16+ Years', '15 Tours', 'Scorpio-N', '18 / 18', '10 Bullets', '45+ Bikes', 'Right Raider (Speed Baulk & Corner Specialist)', 'Jump Escape, Touch, Body Swerve, Rapid Toe Touch')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 5. INTERNATIONAL TOURS TABLE (Public Read, Administrator-Only Write)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.international_tours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country TEXT NOT NULL,
  tour_count INTEGER NOT NULL DEFAULT 1,
  flag_code TEXT NOT NULL,
  key_cups TEXT,
  display_order INTEGER NOT NULL DEFAULT 10
);

ALTER TABLE public.international_tours ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read tours" ON public.international_tours;
DROP POLICY IF EXISTS "Allow admin modify tours" ON public.international_tours;

CREATE POLICY "Allow public read tours"
  ON public.international_tours
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Allow admin modify tours"
  ON public.international_tours
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

REVOKE ALL ON public.international_tours FROM anon, authenticated;
GRANT SELECT ON public.international_tours TO anon, authenticated;
GRANT ALL ON public.international_tours TO authenticated;

INSERT INTO public.international_tours (country, tour_count, flag_code, key_cups, display_order)
VALUES 
  ('Canada', 9, 'ca', 'Vancouver, Calgary, Brampton & Toronto Gold Cups', 1),
  ('USA', 2, 'us', 'Bay Area Kabaddi Championship & Yuba City Gold Cup', 2),
  ('Australia', 2, 'au', 'Melbourne & Sydney Open Tournaments', 3),
  ('Malaysia', 1, 'my', 'Kuala Lumpur International Invitational', 4),
  ('Europe', 1, 'eu', 'UK & EU International Kabaddi Championship', 5)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------------------
-- 6. TOURNAMENT RECORDS TABLE (Public Read, Administrator-Only Write)
-- ------------------------------------------------------------------------------
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

ALTER TABLE public.tournament_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read tournaments" ON public.tournament_records;
DROP POLICY IF EXISTS "Allow admin modify tournaments" ON public.tournament_records;

CREATE POLICY "Allow public read tournaments"
  ON public.tournament_records
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Allow admin modify tournaments"
  ON public.tournament_records
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

REVOKE ALL ON public.tournament_records FROM anon, authenticated;
GRANT SELECT ON public.tournament_records TO anon, authenticated;
GRANT ALL ON public.tournament_records TO authenticated;

-- Seed confirmed victories (Lead Raider honors)
INSERT INTO public.tournament_records (year, title, location, award, prize, category, verified)
VALUES
  (2025, 'Bir Baba Buddha Sahib Kabaddi Cup', 'Tarn Taran, Punjab', 'Best Raider of Tournament', 'Mahindra Scorpio-N SUV', 'major_cup', true),
  (2024, '1st Frandipur Kabaddi Cup Championship', 'Frandipur, Punjab', 'Best Raider & 18/18 Strike', 'Trophy & Prize Buffalo', 'major_cup', true),
  (2024, 'Vancouver International Kabaddi Cup', 'Vancouver, BC, Canada', 'Best Raider of the Tournament', 'Trophy & Cash Award', 'international', true),
  (2023, 'Toronto Metro Championship', 'Brampton / Toronto, Canada', 'Best Raider / Lead Scorer', 'Championship Trophy', 'international', true),
  (2023, 'Punjab State Federation Cup', 'Punjab, India', 'Best Raider Recognition', 'Royal Enfield Bullet 350', 'major_cup', true)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------------------
-- 7. STORAGE BUCKET CONFIGURATION (athlete-media: Public Read, Admin Write Only)
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('athlete-media', 'athlete-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public media read access" ON storage.objects;
DROP POLICY IF EXISTS "Public media access" ON storage.objects;
DROP POLICY IF EXISTS "Admin upload media access" ON storage.objects;
DROP POLICY IF EXISTS "Admin upload media" ON storage.objects;
DROP POLICY IF EXISTS "Admin modify media access" ON storage.objects;
DROP POLICY IF EXISTS "Admin update media" ON storage.objects;
DROP POLICY IF EXISTS "Admin delete media access" ON storage.objects;
DROP POLICY IF EXISTS "Admin delete media" ON storage.objects;

-- Public can view media assets
CREATE POLICY "Public media read access"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'athlete-media');

-- ONLY verified administrators can upload media assets
CREATE POLICY "Admin upload media access"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'athlete-media'
    AND public.is_admin()
  );

-- ONLY verified administrators can update media assets
CREATE POLICY "Admin modify media access"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'athlete-media'
    AND public.is_admin()
  )
  WITH CHECK (
    bucket_id = 'athlete-media'
    AND public.is_admin()
  );

-- ONLY verified administrators can delete media assets
CREATE POLICY "Admin delete media access"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'athlete-media'
    AND public.is_admin()
  );

-- ------------------------------------------------------------------------------
-- 8. PERFORMANCE INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_enquiries_created_at ON public.enquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_enquiries_status ON public.enquiries (status);
CREATE INDEX IF NOT EXISTS idx_tournaments_year ON public.tournament_records (year DESC);
CREATE INDEX IF NOT EXISTS idx_admin_users_role ON public.admin_users (role);

-- ==============================================================================
-- BOOTSTRAP INSTRUCTIONS (Run in Supabase Dashboard SQL Editor after running schema)
-- ==============================================================================
-- Step A: In Supabase Dashboard -> Authentication -> Users, invite or create your admin user:
--         Email: admin@gurlalsohal.com (or your choice)
-- Step B: Copy the generated User UID from the Auth Users list.
-- Step C: Run this query to grant administrator status:
--
-- INSERT INTO public.admin_users (user_id, role, notes)
-- VALUES ('<PASTE-ADMIN-USER-UUID-HERE>', 'superadmin', 'Initial Authorized Management Admin')
-- ON CONFLICT (user_id) DO NOTHING;
-- ==============================================================================
