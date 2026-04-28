#!/usr/bin/env python3
"""
Wrap latitude/longitude in geomap panel SQL with lat_for_map / lng_for_map
PostgreSQL functions, so that coordinate transformation (WGS-84 → GCJ-02)
is applied automatically when user picks 高德地图 from the map_url dropdown.

Run from repo root:
  python3 scripts/wrap-coord-with-map-fn.py

Each replacement is keyed by (file, panel_id, ref_id) for safety.
The script verifies old SQL matches before applying — bails out if drift detected.
"""
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

REPLACEMENTS = [
    # --- 简单模式：SELECT $__time(date), latitude, longitude FROM positions ---
    {
        "file": "grafana/dashboards/zh-cn/CurrentChargeView.json",
        "panel_id": 50,
        "ref_id": "A",
        "old": (
            "SELECT\n"
            "  $__time(date),\n"
            "  latitude,\n"
            "  longitude\n"
            "FROM positions\n"
            "WHERE\n"
            "  car_id = $car_id AND\n"
            "  $__timeFilter(date)\n"
            "ORDER BY\n"
            "  date ASC"
        ),
        "new": (
            "SELECT\n"
            "  $__time(date),\n"
            "  lat_for_map('${map_url}', latitude, longitude) AS latitude,\n"
            "  lng_for_map('${map_url}', latitude, longitude) AS longitude\n"
            "FROM positions\n"
            "WHERE\n"
            "  car_id = $car_id AND\n"
            "  $__timeFilter(date)\n"
            "ORDER BY\n"
            "  date ASC"
        ),
    },
    {
        "file": "grafana/dashboards/zh-cn/CurrentDriveView.json",
        "panel_id": 33,
        "ref_id": "A",
        "old": (
            "SELECT\n"
            "  $__time(date),\n"
            "  latitude,\n"
            "  longitude\n"
            "FROM positions\n"
            "WHERE \n"
            "  car_id = $car_id AND \n"
            "  $__timeFilter(date)\n"
            "ORDER BY \n"
            "  date ASC"
        ),
        "new": (
            "SELECT\n"
            "  $__time(date),\n"
            "  lat_for_map('${map_url}', latitude, longitude) AS latitude,\n"
            "  lng_for_map('${map_url}', latitude, longitude) AS longitude\n"
            "FROM positions\n"
            "WHERE \n"
            "  car_id = $car_id AND \n"
            "  $__timeFilter(date)\n"
            "ORDER BY \n"
            "  date ASC"
        ),
    },
    {
        "file": "grafana/dashboards/zh-cn/CurrentState.json",
        "panel_id": 86,
        "ref_id": "A",
        "old": (
            "SELECT\n"
            "  $__time(date),\n"
            "  latitude,\n"
            "  longitude\n"
            "FROM positions\n"
            "WHERE \n"
            "  car_id = $car_id AND \n"
            "  $__timeFilter(date)\n"
            "ORDER BY \n"
            "  date ASC"
        ),
        "new": (
            "SELECT\n"
            "  $__time(date),\n"
            "  lat_for_map('${map_url}', latitude, longitude) AS latitude,\n"
            "  lng_for_map('${map_url}', latitude, longitude) AS longitude\n"
            "FROM positions\n"
            "WHERE \n"
            "  car_id = $car_id AND \n"
            "  $__timeFilter(date)\n"
            "ORDER BY \n"
            "  date ASC"
        ),
    },
    {
        "file": "grafana/dashboards/zh-cn/CurrentState.json",
        "panel_id": 86,
        "ref_id": "B",
        "old": "select $__time(date),latitude,longitude from positions WHERE car_id = $car_id order by id desc limit 1;",
        "new": (
            "select $__time(date),"
            "lat_for_map('${map_url}', latitude, longitude) AS latitude,"
            "lng_for_map('${map_url}', latitude, longitude) AS longitude "
            "from positions WHERE car_id = $car_id order by id desc limit 1;"
        ),
    },
    {
        "file": "grafana/dashboards/zh-cn/TrackingDrives.json",
        "panel_id": 18,
        "ref_id": "A",
        "old": (
            "WITH journey AS (SELECT start_date, end_date FROM drives WHERE id = $journey)\n"
            "SELECT\n"
            "  $__time(date), latitude, longitude\n"
            "FROM positions, journey\n"
            "WHERE\n"
            "    car_id = $car_id AND (date BETWEEN journey.start_date AND journey.end_date)\n"
            "ORDER BY date ASC"
        ),
        "new": (
            "WITH journey AS (SELECT start_date, end_date FROM drives WHERE id = $journey)\n"
            "SELECT\n"
            "  $__time(date),\n"
            "  lat_for_map('${map_url}', latitude, longitude) AS latitude,\n"
            "  lng_for_map('${map_url}', latitude, longitude) AS longitude\n"
            "FROM positions, journey\n"
            "WHERE\n"
            "    car_id = $car_id AND (date BETWEEN journey.start_date AND journey.end_date)\n"
            "ORDER BY date ASC"
        ),
    },
    {
        "file": "grafana/dashboards/internal/drive-details.json",
        "panel_id": 4,
        "ref_id": "A",
        "old": (
            "SELECT\n"
            "  $__time(date),\n"
            "  latitude,\n"
            "  longitude\n"
            "FROM positions\n"
            "WHERE \n"
            "  car_id = $car_id AND \n"
            "  $__timeFilter(date)\n"
            "ORDER BY \n"
            "  date ASC"
        ),
        "new": (
            "SELECT\n"
            "  $__time(date),\n"
            "  lat_for_map('${map_url}', latitude, longitude) AS latitude,\n"
            "  lng_for_map('${map_url}', latitude, longitude) AS longitude\n"
            "FROM positions\n"
            "WHERE \n"
            "  car_id = $car_id AND \n"
            "  $__timeFilter(date)\n"
            "ORDER BY \n"
            "  date ASC"
        ),
    },
    # --- 聚合模式：avg(lat) AS latitude ---
    {
        "file": "grafana/dashboards/zh-cn/trip.json",
        "panel_id": 6,
        "ref_id": "A",
        "old": (
            "with unioned_positions as (\n"
            "\n"
            "    -- fetch all positions based on start_date of drives so the map aligns with data shown in other panels\n"
            "    select p.*\n"
            "    from positions p\n"
            "             inner join drives d on p.drive_id = d.id\n"
            "    where p.car_id = $car_id and $__timeFilter(d.start_date)\n"
            "\n"
            "    union all\n"
            "\n"
            "    -- get all positions logged while not driving\n"
            "    select *\n"
            "    from positions p\n"
            "    where p.car_id = $car_id and drive_id is null and $__timeFilter(date))\n"
            "\n"
            "SELECT $__timeGroup(date, '5s')      AS time,\n"
            "       avg(latitude)                           AS latitude,\n"
            "       avg(longitude)                          AS longitude\n"
            "from unioned_positions\n"
            "GROUP BY 1\n"
            "ORDER BY 1 ASC"
        ),
        "new": (
            "with unioned_positions as (\n"
            "\n"
            "    -- fetch all positions based on start_date of drives so the map aligns with data shown in other panels\n"
            "    select p.*\n"
            "    from positions p\n"
            "             inner join drives d on p.drive_id = d.id\n"
            "    where p.car_id = $car_id and $__timeFilter(d.start_date)\n"
            "\n"
            "    union all\n"
            "\n"
            "    -- get all positions logged while not driving\n"
            "    select *\n"
            "    from positions p\n"
            "    where p.car_id = $car_id and drive_id is null and $__timeFilter(date))\n"
            "\n"
            "SELECT $__timeGroup(date, '5s')      AS time,\n"
            "       lat_for_map('${map_url}', avg(latitude), avg(longitude))  AS latitude,\n"
            "       lng_for_map('${map_url}', avg(latitude), avg(longitude))  AS longitude\n"
            "from unioned_positions\n"
            "GROUP BY 1\n"
            "ORDER BY 1 ASC"
        ),
    },
    {
        "file": "grafana/dashboards/zh-cn/visited.json",
        "panel_id": 2,
        "ref_id": "Positions",
        "old": (
            "SELECT\n"
            "  date_trunc('minute', timezone('UTC', date), '$__timezone') as time,\n"
            "  avg(latitude) as latitude,\n"
            "  avg(longitude) as longitude\n"
            "FROM\n"
            "  positions\n"
            "WHERE\n"
            "  car_id = $car_id AND $__timeFilter(date) and ideal_battery_range_km is not null\n"
            "GROUP BY 1\n"
            "ORDER BY 1"
        ),
        "new": (
            "SELECT\n"
            "  date_trunc('minute', timezone('UTC', date), '$__timezone') as time,\n"
            "  lat_for_map('${map_url}', avg(latitude), avg(longitude)) as latitude,\n"
            "  lng_for_map('${map_url}', avg(latitude), avg(longitude)) as longitude\n"
            "FROM\n"
            "  positions\n"
            "WHERE\n"
            "  car_id = $car_id AND $__timeFilter(date) and ideal_battery_range_km is not null\n"
            "GROUP BY 1\n"
            "ORDER BY 1"
        ),
    },
    # --- CTE 外包模式：charging-stats 在 outer SELECT 包装 ---
    {
        "file": "grafana/dashboards/zh-cn/charging-stats.json",
        "panel_id": 24,
        "ref_id": "A",
        "old": (
            "WITH charge_data AS (\n"
            "SELECT COALESCE(geofence.name, CONCAT_WS(', ', COALESCE(address.name, nullif(CONCAT_WS(' ', address.road, address.house_number), '')), address.city)) AS loc_nm\n"
            ", AVG(position.latitude) AS latitude\n"
            ", AVG(position.longitude) AS longitude\n"
            ", sum(charge.charge_energy_added) AS chg_total\n"
            ", count(*) as charges\n"
            "FROM charging_processes charge\n"
            "LEFT JOIN addresses address ON charge.address_id = address.id\n"
            "LEFT JOIN positions position ON charge.position_id = position.id\n"
            "LEFT JOIN geofences geofence ON charge.geofence_id = geofence.id\n"
            "WHERE $__timeFilter(charge.end_date)\n"
            "AND charge.duration_min >= $min_duration\n"
            "AND charge.car_id = $car_id\n"
            "GROUP BY COALESCE(geofence.name, CONCAT_WS(', ', COALESCE(address.name, nullif(CONCAT_WS(' ', address.road, address.house_number), '')), address.city))\n"
            ") \n"
            "SELECT loc_nm\n"
            "\t,latitude\n"
            "\t,longitude\n"
            "\t,chg_total\n"
            "\t,chg_total * 1.0 / (SELECT sum(chg_total) FROM charge_data) * 100   AS pct\n"
            "\t,charges\n"
            "FROM charge_data"
        ),
        "new": (
            "WITH charge_data AS (\n"
            "SELECT COALESCE(geofence.name, CONCAT_WS(', ', COALESCE(address.name, nullif(CONCAT_WS(' ', address.road, address.house_number), '')), address.city)) AS loc_nm\n"
            ", AVG(position.latitude) AS latitude\n"
            ", AVG(position.longitude) AS longitude\n"
            ", sum(charge.charge_energy_added) AS chg_total\n"
            ", count(*) as charges\n"
            "FROM charging_processes charge\n"
            "LEFT JOIN addresses address ON charge.address_id = address.id\n"
            "LEFT JOIN positions position ON charge.position_id = position.id\n"
            "LEFT JOIN geofences geofence ON charge.geofence_id = geofence.id\n"
            "WHERE $__timeFilter(charge.end_date)\n"
            "AND charge.duration_min >= $min_duration\n"
            "AND charge.car_id = $car_id\n"
            "GROUP BY COALESCE(geofence.name, CONCAT_WS(', ', COALESCE(address.name, nullif(CONCAT_WS(' ', address.road, address.house_number), '')), address.city))\n"
            ") \n"
            "SELECT loc_nm\n"
            "\t,lat_for_map('${map_url}', latitude, longitude) AS latitude\n"
            "\t,lng_for_map('${map_url}', latitude, longitude) AS longitude\n"
            "\t,chg_total\n"
            "\t,chg_total * 1.0 / (SELECT sum(chg_total) FROM charge_data) * 100   AS pct\n"
            "\t,charges\n"
            "FROM charge_data"
        ),
    },
    # --- unnest 模式：charge-details 双元素对称包装 ---
    {
        "file": "grafana/dashboards/internal/charge-details.json",
        "panel_id": 4,
        "ref_id": "A",
        "old": (
            "SELECT\n"
            "\t$__time(date),\n"
            "\tunnest(ARRAY[latitude, latitude]) AS latitude,\n"
            "\tunnest(ARRAY[longitude, longitude]) AS longitude\n"
            "FROM\n"
            "\tcharging_processes c\n"
            "\tJOIN positions p ON c.position_id = p.id\n"
            "WHERE\n"
            "\t$__timeFilter(date)\n"
            "\tAND c.car_id = $car_id;"
        ),
        "new": (
            "SELECT\n"
            "\t$__time(date),\n"
            "\tunnest(ARRAY[lat_for_map('${map_url}', latitude, longitude), lat_for_map('${map_url}', latitude, longitude)]) AS latitude,\n"
            "\tunnest(ARRAY[lng_for_map('${map_url}', latitude, longitude), lng_for_map('${map_url}', latitude, longitude)]) AS longitude\n"
            "FROM\n"
            "\tcharging_processes c\n"
            "\tJOIN positions p ON c.position_id = p.id\n"
            "WHERE\n"
            "\t$__timeFilter(date)\n"
            "\tAND c.car_id = $car_id;"
        ),
    },
]


def detect_format(text: str):
    return 2 if text.lstrip().startswith("{\n") else None


def apply_replacement(rep):
    path = REPO_ROOT / rep["file"]
    text = path.read_text()
    indent = detect_format(text)
    d = json.loads(text)

    panel = next((p for p in d["panels"] if p.get("id") == rep["panel_id"]), None)
    if panel is None:
        return False, f"panel id={rep['panel_id']} not found"

    target = next((t for t in panel.get("targets", []) if t.get("refId") == rep["ref_id"]), None)
    if target is None:
        return False, f"refId={rep['ref_id']} not found in panel {rep['panel_id']}"

    current = target.get("rawSql", "")
    if current == rep["new"]:
        return False, "already wrapped, skipped"
    if current != rep["old"]:
        return False, "SQL drift detected — old SQL doesn't match expected, manual review needed"

    target["rawSql"] = rep["new"]

    if indent is None:
        out = json.dumps(d, ensure_ascii=False, separators=(",", ":"))
    else:
        out = json.dumps(d, ensure_ascii=False, indent=indent)
        if text.endswith("\n"):
            out += "\n"
    path.write_text(out)
    return True, f"wrapped panel {rep['panel_id']} refId={rep['ref_id']}"


def main():
    failed = 0
    for rep in REPLACEMENTS:
        ok, msg = apply_replacement(rep)
        mark = "✓" if ok else "·"
        print(f"  {mark} {rep['file']}: {msg}")
        if not ok and "drift" in msg:
            failed += 1
    if failed:
        print(f"\n{failed} drift(s) — review manually")
        sys.exit(1)


if __name__ == "__main__":
    main()
