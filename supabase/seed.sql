-- Insert status codes
INSERT INTO status_code (status_code, status_name, sequence_no, is_terminal) VALUES
('REGISTERED', 'Registered', 1, false),
('PICKED_UP', 'Picked Up', 2, false),
('IN_TRANSIT', 'In Transit', 3, false),
('OUT_FOR_DELIVERY', 'Out For Delivery', 4, false),
('DELIVERED', 'Delivered', 5, true),
('RETURNED', 'Returned', 6, true)
ON CONFLICT (status_code) DO NOTHING;

-- Since exact approved service types, transit hubs, etc., are not fully specified with counts and details,
-- I am deferring seeding of the remaining reference data, customers, staff, drivers, vehicles, packages,
-- and events (like the 12 packages, 61 tracking events, 7 hubs, and 7 drivers) to Phase 3
-- to avoid inventing unapproved data.
