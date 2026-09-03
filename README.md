# CS6.302- Software System Development 

Assignment 1- Database Design

## Team and Project Details

**Group:** 2

**Project:** 3 StaySpot– Vacation Rental & Experiences

**Team Members:**
- Anirudh Bandi [2026201058]
- Dhruv Bhuva []
- Lakshyajeet Singh Jalal [2026201063]
- Thejas Gowda [2026201023]

## Setup Instructions (Windows, MacOS, Linux)

1. Install [VS Code](https://code.visualstudio.com/) & [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Clone the repository and open it in VS Code

    ```sh
    git clone https://github.com/mglsj/ssd-a1-g2.git
    ```

    ```sh
    cd ssd-a1-g2
    ```

    ```sh
    code .
    ```

3. Install **Dev Containers** extension [`ms-vscode-remote.remote-containers`] in VS Code
4. Open the project in a Dev Container
    - `CTRL+SHIFT+P` / `CMD+SHIFT+P` and select
    - `Dev Containers: Rebuild and Reopen in Container`
5. Wait for the container to build and open the project in a new VS Code window (5-10 minutes on first build)

### Connecting to the Postgres Database

#### Inside the Dev Container terminal

```sh
psql -h postgres -U postgres -d postgres
```

#### Outside the Dev Container

Connection String:
```sh
psql postgresql://postgres:postgres@localhost:5432/postgres
```

# StaySpot Hybrid Database Architecture

A production-grade hybrid database architecture combining **PostgreSQL** (for ACID-compliant transactional booking management, audit trails, and financial analytics) and **MongoDB** (for high-throughput geospatial search telemetry and multi-faceted review analytics).

---

## Directory Structure

```text
.
├── README.md                          # Architecture documentation & execution plans
├── docs/
│   ├── relational_erd.png             # PostgreSQL Relational ERD
│   └── mongo_schema_map.json          # MongoDB JSON schema validation models
├── sql/
│   ├── 01_schema_ddl.sql              # Table DDL, PK/FKs, and CHECK constraints
│   ├── 02_indexes.sql                 # Secondary and partial indexes
│   ├── 03_triggers_and_audit.sql      # Wallet change audit logging triggers
│   ├── 04_stored_procedures.sql       # Atomic booking PL/pgSQL stored procedure
│   ├── 05_materialized_views.sql      # Refreshable revenue materialized view
│   └── 06_window_analytics.sql        # 7-day moving average & dense rank analytics
├── mongo/
│   ├── jsconfig.json                  # TypeScript compiler configuration
│   ├── package.json                   # Node.js typecheck dependencies
│   ├── 01_collections_and_indexes.js  # Schema validation, 2dsphere, and TTL indexes
│   ├── 02_workflow3_geonear.js        # Geospatial aggregation pipeline ($geoNear)
│   └── 03_workflow4_facet.js          # Multi-faceted analytics pipeline ($facet)
├── data_generation/
│   ├── postgres_seeder.py             # Generates 100k+ ledger/audit records
│   ├── mongo_seeder.py                # Generates 500k+ geospatial telemetry pings
│   └── requirements.txt               # Python dependencies
└── performance/
    ├── postgres_explain_analyzes.txt  # Raw EXPLAIN (ANALYZE, BUFFERS) output
    └── mongo_execution_stats.json     # Raw explain("executionStats") JSON

```

## Setup & Execution Instructions

### 1. Database Schema & Setup

#### PostgreSQL Setup
```sh
psql -h postgres -U postgres -d postgres -f sql/01_schema_ddl.sql
psql -h postgres -U postgres -d postgres -f sql/02_indexes.sql
psql -h postgres -U postgres -d postgres -f sql/03_triggers_and_audit.sql
psql -h postgres -U postgres -d postgres -f sql/04_stored_procedures.sql
psql -h postgres -U postgres -d postgres -f sql/05_materialized_views.sql
```

#### MongoDB Setup
```sh
mongosh "mongodb://mongo:27017/StaySpot" mongo/01_collections_and_indexes.js
```
### 2. Mock Data Seeding

```sh
# Seed PostgreSQL transactional & audit ledger data
uv run python data_generation/postgres_seeder.py

# Seed MongoDB geospatial telemetry & review collections
MONGO_URI="mongodb://mongo:27017" uv run python data_generation/mongo_seeder.py
```

### 3. Analytics & Workflows Execution
```sh
# Workflow 2: PostgreSQL Window Analytics
psql -h postgres -U postgres -d postgres -f sql/06_window_analytics.sql

# Workflow 3: MongoDB Geospatial Hotspot Aggregation ($geoNear)
mongosh "mongodb://mongo:27017/StaySpot" mongo/02_workflow3_geonear.js

# Workflow 4: MongoDB Multi-Faceted Review Analytics ($facet)
mongosh "mongodb://mongo:27017/StaySpot" mongo/03_workflow4_facet.js
```

### 4. Schema Type Validation
```sh
cd mongo && npm run typecheck
```



## Performance Proof & Execution Plans

### Workflow 2: PostgreSQL 7-Day Revenue Moving Average
Query Pattern: Aggregates daily property revenue using CTEs, calculating a 7-day moving window frame (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) alongside DENSE_RANK().

Index Strategy: Utilizes index idx_bookings_property_status_date on (property_id, status, created_at).

Execution Proof: Eliminates full sequential scans by filtering directly on status = 'CONFIRMED' via index scan.

Full Output: performance/postgres_explain_analyzes.txt

### Workflow 3: MongoDB Geospatial Aggregation ($geoNear)
Query Pattern: Clusters search sessions within a 5km radius (maxDistance: 5000) around coordinates [-122.4194, 37.7749].

Index Strategy: Leverages compound 2dsphere index idx_sessions_geo_recent on { location: "2dsphere", created_at: -1 }.

Execution Proof: Bypasses document-level scans by using 2D sphere geometry indexing for fast spatial lookup.

Full Output: performance/mongo_execution_stats.json

### Workflow 4: MongoDB Multi-Faceted Review Analytics ($facet)
Query Pattern: Aggregates rating distributions, unrolls location_tags via $unwind for frequency counting, and computes global rating metrics in a single pipeline execution.

Index Strategy: Utilizes index idx_reviews_property_recent on { property_id: 1, created_at: -1 }.

Full Output: performance/mongo_execution_stats.json

