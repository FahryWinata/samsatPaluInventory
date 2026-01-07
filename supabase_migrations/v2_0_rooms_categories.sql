-- v2.0 Migration: Rooms, Asset Categories, and Flexible Assignment
-- Run this in Supabase SQL Editor

-- =============================================
-- 1. Create rooms table
-- =============================================
CREATE TABLE IF NOT EXISTS rooms (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  building VARCHAR(100),
  floor VARCHAR(20),
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

-- RLS Policy (allow all for authenticated users)
CREATE POLICY "Allow all for authenticated users" ON rooms
  FOR ALL USING (true) WITH CHECK (true);

-- =============================================
-- 2. Create asset_categories table
-- =============================================
CREATE TABLE IF NOT EXISTS asset_categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  identifier_type VARCHAR(20) DEFAULT 'none',  -- 'serial_number', 'vehicle_id', 'room_tag', 'none'
  requires_person BOOLEAN DEFAULT true,
  requires_room BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE asset_categories ENABLE ROW LEVEL SECURITY;

-- RLS Policy
CREATE POLICY "Allow all for authenticated users" ON asset_categories
  FOR ALL USING (true) WITH CHECK (true);

-- Seed default categories
INSERT INTO asset_categories (name, identifier_type, requires_person, requires_room) VALUES
  ('Laptop', 'serial_number', true, false),
  ('PC/Komputer', 'serial_number', true, false),
  ('Printer', 'serial_number', false, true),
  ('Kendaraan', 'vehicle_id', true, false),
  ('Furnitur', 'none', false, true),
  ('AC', 'none', false, true),
  ('Kipas Angin', 'none', false, true),
  ('Lainnya', 'none', true, false)
ON CONFLICT DO NOTHING;

-- =============================================
-- 3. Modify assets table
-- =============================================

-- Add category_id column
ALTER TABLE assets 
  ADD COLUMN IF NOT EXISTS category_id INT REFERENCES asset_categories(id);

-- Add assigned_to_room_id column
ALTER TABLE assets 
  ADD COLUMN IF NOT EXISTS assigned_to_room_id INT REFERENCES rooms(id);

-- Rename serial_number to identifier_value (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'assets' AND column_name = 'serial_number') THEN
    ALTER TABLE assets RENAME COLUMN serial_number TO identifier_value;
  END IF;
END $$;

-- Make identifier_value nullable (if not already)
ALTER TABLE assets ALTER COLUMN identifier_value DROP NOT NULL;

-- =============================================
-- 4. Update trigger for updated_at
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for rooms
DROP TRIGGER IF EXISTS update_rooms_updated_at ON rooms;
CREATE TRIGGER update_rooms_updated_at
  BEFORE UPDATE ON rooms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for asset_categories
DROP TRIGGER IF EXISTS update_asset_categories_updated_at ON asset_categories;
CREATE TRIGGER update_asset_categories_updated_at
  BEFORE UPDATE ON asset_categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
