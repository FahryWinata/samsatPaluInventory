-- Indexes for Assets Table
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_assets_name ON assets(name);
CREATE INDEX IF NOT EXISTS idx_assets_identifier ON assets(identifier_value);
-- Correct column name for room relationship
CREATE INDEX IF NOT EXISTS idx_assets_room ON assets(assigned_to_room_id);
-- Index for maintenance optimization
CREATE INDEX IF NOT EXISTS idx_assets_updated_at ON assets(updated_at);

-- Indexes for Inventory Table
CREATE INDEX IF NOT EXISTS idx_inventory_name ON inventory(name);
CREATE INDEX IF NOT EXISTS idx_inventory_quantity ON inventory(quantity);
