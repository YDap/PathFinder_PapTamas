-- Add ratings table
CREATE TABLE place_ratings (
    id SERIAL PRIMARY KEY,
    place_id TEXT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    user_id TEXT, -- Optional, for user identification
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX idx_place_ratings_place_id ON place_ratings(place_id);

-- Update the view to include average rating
-- Assuming the current view is something like:
-- CREATE VIEW v_places_basic AS SELECT id, name, category, elevation_m, latitude, longitude FROM places;

-- Drop and recreate the view with average rating
DROP VIEW IF EXISTS v_places_basic;
CREATE VIEW v_places_basic AS
SELECT
    p.id,
    p.name,
    p.category,
    p.elevation_m,
    p.latitude,
    p.longitude,
    AVG(r.rating) AS average_rating
FROM places p
LEFT JOIN place_ratings r ON p.id = r.place_id
GROUP BY p.id, p.name, p.category, p.elevation_m, p.latitude, p.longitude;