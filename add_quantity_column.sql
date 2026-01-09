-- Add quantity column to assets table
ALTER TABLE public.assets 
ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1;

-- Add check constraint to ensure quantity is positive
ALTER TABLE public.assets 
ADD CONSTRAINT quantity_positive CHECK (quantity > 0);

-- Comment on column
COMMENT ON COLUMN public.assets.quantity IS 'Number of items for bulk assets. Default is 1.';
