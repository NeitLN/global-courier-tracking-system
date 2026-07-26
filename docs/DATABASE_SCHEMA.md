# Database Schema

## Overview
This document outlines the Phase 2 structural schema implementation for the Global Courier & Tracking System. It establishes the 13 approved domain relations, primary and alternate keys, foreign keys, constraints, and indexes. 

## Domain Tables (13)
1. `status_code`: Reference table for package statuses.
2. `service_type`: Reference table for service tiers and rates.
3. `customer`: Users who send or receive packages.
4. `transit_hub`: Physical locations in the network.
5. `staff`: Hub workers.
6. `driver`: Delivery and transport drivers.
7. `vehicle`: Transport vehicles.
8. `route`: Directed paths between two hubs.
9. `package`: Shipped items.
10. `tracking_event`: Authoritative history of package statuses.
11. `trip`: Executed instances of a route by a driver and vehicle.
12. `package_leg`: Packages loaded onto a trip.
13. `delivery_attempt`: Driver attempts to deliver a package.

## Foreign Key Actions

| Source Table | Source Column | Target Table | Target Column | ON UPDATE | ON DELETE | Reason |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `staff` | `hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Staff must be linked to an existing hub; history relies on it. |
| `driver` | `base_hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Driver must be linked to an existing hub; history relies on it. |
| `vehicle` | `home_hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Vehicle must be linked to an existing hub. |
| `route` | `origin_hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Route depends on existing origin. |
| `route` | `dest_hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Route depends on existing destination. |
| `package` | `sender_id` | `customer` | `customer_id` | NO ACTION | RESTRICT | Package requires a sender. |
| `package` | `receiver_id` | `customer` | `customer_id` | NO ACTION | RESTRICT | Package requires a receiver. |
| `package` | `service_id` | `service_type` | `service_id` | NO ACTION | RESTRICT | Package requires a valid service type. |
| `package` | `origin_hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Package requires origin hub. |
| `package` | `dest_hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | Package requires destination hub. |
| `package` | `current_status` | `status_code` | `status_code` | NO ACTION | RESTRICT | Package requires valid status. |
| `tracking_event` | `package_id` | `package` | `package_id` | NO ACTION | RESTRICT | Tracking history is authoritative, shouldn't be deleted with package blindly. |
| `tracking_event` | `hub_id` | `transit_hub` | `hub_id` | NO ACTION | RESTRICT | A hub referenced in history cannot be deleted (R12). |
| `tracking_event` | `status_code` | `status_code` | `status_code` | NO ACTION | RESTRICT | History requires valid status. |
| `tracking_event` | `recorded_by` | `staff` | `staff_id` | NO ACTION | RESTRICT | Preserves audit trail for staff. |
| `trip` | `route_id` | `route` | `route_id` | NO ACTION | RESTRICT | Trip requires route. |
| `trip` | `vehicle_id` | `vehicle` | `vehicle_id` | NO ACTION | RESTRICT | Trip requires vehicle. |
| `trip` | `driver_id` | `driver` | `driver_id` | NO ACTION | RESTRICT | Trip requires driver. |
| `package_leg` | `trip_id` | `trip` | `trip_id` | NO ACTION | CASCADE | Association row cleanup is safe if a trip is deleted (does not affect tracking_event). |
| `package_leg` | `package_id` | `package` | `package_id` | NO ACTION | RESTRICT | Do not delete packages if leg is deleted. |
| `delivery_attempt` | `package_id` | `package` | `package_id` | NO ACTION | RESTRICT | Attempt requires valid package. |
| `delivery_attempt` | `driver_id` | `driver` | `driver_id` | NO ACTION | RESTRICT | Attempt requires valid driver. |

## Structural Rule Mapping
- **R1:** `sender_id <> receiver_id` enforced via CHECK on `package`.
- **R2:** Tracking number uniqueness enforced via UNIQUE constraint on `package.tracking_no`.
- **R4:** Origin <> Destination enforced via CHECK on `route`. Uniqueness enforced via UNIQUE constraint on `(origin_hub_id, dest_hub_id, mode)`.
- **R5:** No double booking enforced via UNIQUE constraints on `trip(vehicle_id, depart)` and `trip(driver_id, depart)`.
- **R8:** Attempt outcome/reason consistency enforced via CHECK on `delivery_attempt`.
- **R10:** Positive weights/values enforced via CHECKs on `package`, `vehicle`, and `service_type` (zero and negative tests explicitly included).
- **R12:** Hub deletion restricted via ON DELETE RESTRICT on `tracking_event.hub_id`.

## Deferred Rules (Phase 3)
- R3 (F3 workflow insertions)
- R6 (status flow transition logic)
- R7 (append-only enforcement via RLS/triggers)
- R9 (shipping fee calculation)
- R10 cross-table tier-weight validation
- Trigger-maintained `package.current_status` cache

## Index Inventory
Constraint-backed indexes are automatically created for all Primary Keys and UNIQUE constraints.

Explicit Indexes:
- `idx_package_current_status`: On `package(current_status)` to support listing packages by status. Non-redundant as it's not a PK/UQ.
- `idx_package_origin_dest`: On `package(origin_hub_id, dest_hub_id)` for routing queries.
- `idx_tracking_event_hub_time`: On `tracking_event(hub_id, event_time)` for querying events by hub and time. 

Phase 3 Explicit Indexes:
- `idx_delivery_attempt_driver_time`: On `delivery_attempt(driver_id, attempt_time)` for driver ranking.
- `idx_tracking_event_pkg_time_desc`: On `tracking_event(package_id, event_time DESC)` primarily supports F4 table-wide latest-event window ordering.
- `idx_tracking_event_status_time`: General/forward-looking index on `tracking_event(status_code, event_time)` for status flow history queries.
- `idx_package_service`: On `package(service_id)` supports package-to-service FK joins and possible service-scoped access.
- `idx_trip_route_depart`: Explicitly labelled forward-looking index on `trip(route_id, depart)` for future route trip matching.

## Migration Order
1. `20260726165434_create_reference_tables`
2. `20260726165435_create_people_and_assets`
3. `20260726165437_create_routes_packages_and_tracking`
4. `20260726165439_create_transport_and_delivery`
5. `20260726165441_create_domain_indexes`

## Seed Data Status
- 6 approved status rows seeded.
- Seed data for remaining tables (service types, customers, transit hubs, staff, drivers, vehicles, packages, tracking events) deferred to Phase 3 pending fully verified approved values. The exact count of 12 packages, 61 tracking events, 7 hubs, and 7 drivers is deferred and NOT falsely claimed here.

## pgTAP Coverage
Total of 87 explicit assertions run across 5 files:
- `001_domain_schema.test.sql` (14 assertions): includes an exhaustive test verifying that exactly the 13 approved domain tables exist in the public schema.
- `002_keys_and_foreign_keys.test.sql` (50 assertions): explicit tests for all primary keys, alternate keys, and exactly 22 targeted foreign-key relationship proofs.
- `003_constraints.test.sql` (21 assertions): covers rejection tests for R1, R2, R4, R5, R8, and extensive structural negative checks for R10 (zero and negative capacities, rates, etc.).
- `004_referential_actions.test.sql` (1 assertion): verifying R12 hub-history restrict.
- `005_seed_reference_data.test.sql` (1 assertion): verifying seeded status codes.

## Known Limitations
- No frontend UI, RLS, Auth, or business logic functions implemented yet.

## Final Review Validation
- Final domain table count: 13
- Explicit FK relationship tests: 22
- Total pgTAP assertions passing: 87
- All FK actions correctly mapped to ON UPDATE NO ACTION.