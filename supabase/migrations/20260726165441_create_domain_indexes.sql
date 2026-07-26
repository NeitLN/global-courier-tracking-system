-- Indexes for package tracking and querying
CREATE INDEX idx_package_current_status ON package(current_status);
CREATE INDEX idx_package_origin_dest ON package(origin_hub_id, dest_hub_id);

-- Indexes for tracking events (package tracking, hub queries)
CREATE INDEX idx_tracking_event_hub_time ON tracking_event(hub_id, event_time);
