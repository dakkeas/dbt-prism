import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv("secret/.env")

PG_USER = os.getenv("PG_USER")
PG_PASS = os.getenv("PG_PASS")
PG_HOST = os.getenv("PG_HOST")
PG_PORT = os.getenv("PG_PORT")
PG_DB = os.getenv("PG_DB")

SCHEMA_SIZE_QUERY = text(
    """
    select
        schemaname as schema_name,
        round(
            sum(pg_total_relation_size(format('%I.%I', schemaname, tablename)::regclass))
            / 1024.0 / 1024.0 / 1024.0,
            3
        ) as size_gb,
        pg_size_pretty(
            sum(pg_total_relation_size(format('%I.%I', schemaname, tablename)::regclass))
        ) as size_pretty
    from pg_tables
    where schemaname not in ('pg_catalog', 'information_schema')
    group by schemaname
    order by sum(pg_total_relation_size(format('%I.%I', schemaname, tablename)::regclass)) desc
    """
)


def main():
    engine = create_engine(f"postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}")

    with engine.connect() as conn:
        rows = conn.execute(SCHEMA_SIZE_QUERY).mappings().all()

    print(f"{'schema':<32} {'size_gb':>10} {'size_pretty':>14}")
    print("-" * 60)
    for row in rows:
        print(f"{row['schema_name']:<32} {row['size_gb']:>10} {row['size_pretty']:>14}")


if __name__ == "__main__":
    main()
