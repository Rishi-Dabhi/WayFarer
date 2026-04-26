import argparse
import math
import sqlite3

from config import settings


def _distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    radius = 6_371_000
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


parser = argparse.ArgumentParser(description="List WayFarer shops in the local SQLite database")
parser.add_argument("--lat", type=float)
parser.add_argument("--lng", type=float)
parser.add_argument("--radius", type=float, default=2000)
args = parser.parse_args()

con = sqlite3.connect(settings.database_url)
con.row_factory = sqlite3.Row

rows = list(
    con.execute(
        "SELECT id, name, category, latitude, longitude, is_active FROM shops ORDER BY id"
    )
)

print(f"{len(rows)} shops in {settings.database_url}")
for row in rows:
    distance = ""
    in_radius = ""
    if args.lat is not None and args.lng is not None:
        metres = round(_distance_m(args.lat, args.lng, row["latitude"], row["longitude"]))
        distance = f" {metres}m"
        in_radius = " IN" if metres <= args.radius else " OUT"
    print(
        f"{row['id']:>4} {row['name']:<35} {row['category']:<10} "
        f"{row['latitude']:.6f},{row['longitude']:.6f}{distance}{in_radius}"
    )
