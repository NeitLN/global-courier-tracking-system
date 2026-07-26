# Traceability Matrix

This matrix maps required functions (F1-F10) and business rules (R1-R12) to the relevant domain relations.

## Functions

| ID | Description | Primary Domain Relations Affected/Queried |
| :--- | :--- | :--- |
| **F1** | Register and price package | `PACKAGE`, `CUSTOMER`, `SERVICE_TYPE` |
| **F2** | Track package by tracking number | `PACKAGE`, `TRACKING_EVENT`, `STATUS_CODE`, `TRANSIT_HUB` |
| **F3** | Record checkpoint scan | `TRACKING_EVENT`, `PACKAGE`, `STAFF`, `STATUS_CODE` |
| **F4** | List packages currently held at a hub | `PACKAGE`, `TRACKING_EVENT`, `TRANSIT_HUB` |
| **F5** | Update customer details | `CUSTOMER` |
| **F6** | Reconstruct chain of custody (LAG) | `TRACKING_EVENT`, `TRANSIT_HUB`, `PACKAGE` |
| **F7** | Analyse inter-scan intervals (LEAD/CTE) | `TRACKING_EVENT`, `TRANSIT_HUB` |
| **F8** | Measure SLA compliance | `PACKAGE`, `SERVICE_TYPE`, `TRACKING_EVENT` |
| **F9** | Rank driver performance | `DRIVER`, `TRIP`, `DELIVERY_ATTEMPT` |
| **F10**| Find multi-hop routes (Recursive CTE) | `ROUTE`, `TRANSIT_HUB` |

## Business Rules

| ID | Requirement | Primary Domain Relations | Enforcement Mechanism | UI Module | Valid Test | Negative Test | Implementation Phase | Current Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **R1** | A package has one sender and one receiver, and they must differ. | `PACKAGE`, `CUSTOMER` | FK, NOT NULL, CHECK sender_id <> receiver_id | TBD | TBD | sender equals receiver (PLANNED — Phase 2/3 database test suite) | Phase 2/3 | Phase 2 STRUCTURAL IMPLEMENTED |
| **R2** | Tracking number is unique; each package has one service tier. | `PACKAGE`, `SERVICE_TYPE` | UNIQUE tracking_no, NOT NULL FK service_id | TBD | TBD | TBD | Phase 2 | Phase 2 STRUCTURAL IMPLEMENTED |
| **R3** | Each status change creates a tracking event. | `PACKAGE`, `TRACKING_EVENT` | INSERT-only event design and F3 workflow | TBD | TBD | TBD | Phase 3 | Phase 3 IMPLEMENTED AND REMOTELY VERIFIED |
| **R4** | A directed route connects two different hubs. | `ROUTE`, `TRANSIT_HUB` | two FKs, CHECK origin <> destination, UNIQUE origin/destination/mode | TBD | TBD | origin equals destination (PLANNED — Phase 2/3 database test suite) | Phase 2/3 | Phase 2 STRUCTURAL IMPLEMENTED |
| **R5** | Driver and vehicle cannot be double-booked at the same departure time. | `TRIP`, `DRIVER`, `VEHICLE` | UNIQUE driver/departure and vehicle/departure | TBD | TBD | driver double-booking and vehicle double-booking (PLANNED — Phase 2/3 database test suite) | Phase 2/3 | Phase 2 STRUCTURAL IMPLEMENTED |
| **R6** | Status may repeat or advance exactly one step; RETURNED is reachable from any open status; no event follows a terminal status. | `TRACKING_EVENT`, `STATUS_CODE`, `PACKAGE` | status-flow trigger | TBD | TBD | skipped transition, backward transition, event after DELIVERED, event after RETURNED (PLANNED — Phase 3 database test suite) | Phase 3 | Phase 3 IMPLEMENTED AND REMOTELY VERIFIED |
| **R7** | Tracking history is append-only. | `TRACKING_EVENT` | no UPDATE/DELETE application workflow; database privileges/RLS and append-only enforcement | TBD | TBD | UPDATE and DELETE existing tracking events (PLANNED — Phase 3 database test suite) | Phase 3/5 | Phase 3 IMPLEMENTED AND REMOTELY VERIFIED |
| **R8** | Failed delivery requires a reason; successful delivery must not have one. | `DELIVERY_ATTEMPT` | CHECK outcome/failure_reason consistency | TBD | TBD | FAILED without reason and SUCCESS with reason (PLANNED — Phase 2/3 database test suite) | Phase 2/3 | Phase 2 STRUCTURAL IMPLEMENTED |
| **R9** | Shipping fee is calculated from service tariff and actual package weight. | `PACKAGE`, `SERVICE_TYPE` | fn_register_package stored function | TBD | TBD | TBD | Phase 3 | Phase 3 IMPLEMENTED AND REMOTELY VERIFIED |
| **R10** | Weight must be positive and not exceed the tier limit. | `PACKAGE`, `SERVICE_TYPE` | positive-weight CHECK and cross-table function validation | TBD | TBD | zero weight, negative weight and weight above tier limit (PLANNED — Phase 2/3 database test suite) | Phase 2/3 | Phase 2 STRUCTURAL IMPLEMENTED (cross-table deferred to Phase 3) |
| **R11** | Operator scans record staff; system-generated registration may have no staff. | `TRACKING_EVENT`, `STAFF` | nullable recorded_by FK; authenticated operator identity in later workflow | TBD | TBD | TBD | Phase 2 | Phase 2 STRUCTURAL IMPLEMENTED |
| **R12** | A hub referenced in tracking history cannot be deleted. | `TRACKING_EVENT`, `TRANSIT_HUB` | FK ON DELETE RESTRICT | TBD | TBD | delete a hub referenced by tracking history (PLANNED — Phase 2/3 database test suite) | Phase 2/3 | Phase 2 STRUCTURAL IMPLEMENTED |