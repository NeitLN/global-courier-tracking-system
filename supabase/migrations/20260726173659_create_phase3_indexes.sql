-- MIGRATION 4: Phase 3 Supporting Indexes

-- Index for F9 (Driver Performance Ranking)
CREATE INDEX idx_delivery_attempt_driver_time 
ON public.delivery_attempt(driver_id, attempt_time);

-- Index for F4 (Inventory)
-- PostgreSQL can scan UNIQUE(package_id, event_time ASC) backward, but an explicit DESC index primarily supports F4's table-wide latest-event window ordering. Do not claim it is required for R6 point lookup.
CREATE INDEX idx_tracking_event_pkg_time_desc 
ON public.tracking_event(package_id, event_time DESC);

-- General/forward-looking index for querying events by status
CREATE INDEX idx_tracking_event_status_time 
ON public.tracking_event(status_code, event_time);

-- Index supports package-to-service FK joins and possible service-scoped access.
CREATE INDEX idx_package_service 
ON public.package(service_id);

-- Explicitly labelled forward-looking index for future route trip matching
CREATE INDEX idx_trip_route_depart 
ON public.trip(route_id, depart);
