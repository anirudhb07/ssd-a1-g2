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

Connection String:
```sh
postgresql://postgres:postgres@postgres:5432/app
```

PSQL Command Line:
```sh
psql postgresql://postgres:postgres@postgres:5432/app
```

#### Outside the Dev Container

Connection String:
```sh
postgresql://postgres:postgres@localhost:5432/app
```

PSQL Command Line:
```sh
psql postgresql://postgres:postgres@localhost:5432/app
```

### Running Python Scripts

```sh
cd data_generation
```

```sh
uv run postgres_seeder.py
```

```sh
uv run mongo_seeder.py
```

