-- ============================================================================
-- TeslaMate 中文仪表盘：地图坐标转换函数
--
-- 配合 v1.4.2+「地图源」下拉框使用。当用户在仪表盘选中 GCJ-02 系地图
-- (高德 / Google 路网) 时，自动把 TeslaMate 存储的 WGS-84 (GPS 原始)
-- 坐标转为 GCJ-02，让车辆轨迹与瓦片对齐；选中 OSM/Carto/Google 卫星时
-- 直接返回原值。
--
-- 安装：
--   docker exec -i teslamate-database-1 psql -U teslamate teslamate \
--     < sql/install-coord-functions.sql
--
-- 卸载：
--   DROP FUNCTION IF EXISTS lat_for_map(TEXT, DOUBLE PRECISION, DOUBLE PRECISION);
--   DROP FUNCTION IF EXISTS lng_for_map(TEXT, DOUBLE PRECISION, DOUBLE PRECISION);
--   DROP FUNCTION IF EXISTS wgs84_to_gcj02_lat(DOUBLE PRECISION, DOUBLE PRECISION);
--   DROP FUNCTION IF EXISTS wgs84_to_gcj02_lng(DOUBLE PRECISION, DOUBLE PRECISION);
--
-- 算法：eviltransform 标准 (https://github.com/googollee/eviltransform)
-- 精度：中国境内 < 0.5m；境外原样返回
-- ============================================================================

CREATE OR REPLACE FUNCTION wgs84_to_gcj02_lat(wgs_lat DOUBLE PRECISION, wgs_lng DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  a   CONSTANT DOUBLE PRECISION := 6378245.0;
  ee  CONSTANT DOUBLE PRECISION := 0.00669342162296594323;
  x   DOUBLE PRECISION;
  y   DOUBLE PRECISION;
  d_lat       DOUBLE PRECISION;
  rad_lat     DOUBLE PRECISION;
  magic       DOUBLE PRECISION;
  sqrt_magic  DOUBLE PRECISION;
BEGIN
  IF wgs_lat IS NULL OR wgs_lng IS NULL THEN
    RETURN NULL;
  END IF;
  -- 中国境外不做转换
  IF wgs_lng < 72.004 OR wgs_lng > 137.8347
     OR wgs_lat < 0.8293 OR wgs_lat > 55.8271 THEN
    RETURN wgs_lat;
  END IF;
  x := wgs_lng - 105.0;
  y := wgs_lat - 35.0;
  d_lat := -100.0 + 2.0*x + 3.0*y + 0.2*y*y + 0.1*x*y + 0.2*sqrt(abs(x));
  d_lat := d_lat + (20.0*sin(6.0*x*pi()) + 20.0*sin(2.0*x*pi())) * 2.0/3.0;
  d_lat := d_lat + (20.0*sin(y*pi()) + 40.0*sin(y/3.0*pi())) * 2.0/3.0;
  d_lat := d_lat + (160.0*sin(y/12.0*pi()) + 320.0*sin(y*pi()/30.0)) * 2.0/3.0;
  rad_lat := wgs_lat / 180.0 * pi();
  magic := sin(rad_lat);
  magic := 1 - ee * magic * magic;
  sqrt_magic := sqrt(magic);
  d_lat := (d_lat * 180.0) / ((a * (1 - ee)) / (magic * sqrt_magic) * pi());
  RETURN wgs_lat + d_lat;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION wgs84_to_gcj02_lng(wgs_lat DOUBLE PRECISION, wgs_lng DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  a   CONSTANT DOUBLE PRECISION := 6378245.0;
  ee  CONSTANT DOUBLE PRECISION := 0.00669342162296594323;
  x   DOUBLE PRECISION;
  y   DOUBLE PRECISION;
  d_lng       DOUBLE PRECISION;
  rad_lat     DOUBLE PRECISION;
  magic       DOUBLE PRECISION;
  sqrt_magic  DOUBLE PRECISION;
BEGIN
  IF wgs_lat IS NULL OR wgs_lng IS NULL THEN
    RETURN NULL;
  END IF;
  IF wgs_lng < 72.004 OR wgs_lng > 137.8347
     OR wgs_lat < 0.8293 OR wgs_lat > 55.8271 THEN
    RETURN wgs_lng;
  END IF;
  x := wgs_lng - 105.0;
  y := wgs_lat - 35.0;
  d_lng := 300.0 + x + 2.0*y + 0.1*x*x + 0.1*x*y + 0.1*sqrt(abs(x));
  d_lng := d_lng + (20.0*sin(6.0*x*pi()) + 20.0*sin(2.0*x*pi())) * 2.0/3.0;
  d_lng := d_lng + (20.0*sin(x*pi()) + 40.0*sin(x/3.0*pi())) * 2.0/3.0;
  d_lng := d_lng + (150.0*sin(x/12.0*pi()) + 300.0*sin(x*pi()/30.0)) * 2.0/3.0;
  rad_lat := wgs_lat / 180.0 * pi();
  magic := sin(rad_lat);
  magic := 1 - ee * magic * magic;
  sqrt_magic := sqrt(magic);
  d_lng := (d_lng * 180.0) / (a / sqrt_magic * cos(rad_lat) * pi());
  RETURN wgs_lng + d_lng;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- ----------------------------------------------------------------------------
-- 包装函数：根据当前选中的地图源 URL 决定是否做坐标转换
-- 高德 / Google 路网 → GCJ-02 转换；OSM / Carto / Google 卫星 → 原样返回
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION lat_for_map(map_url TEXT, lat DOUBLE PRECISION, lng DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
BEGIN
  -- 仅识别下拉框里的 GCJ-02 来源：高德（autonavi 含路网+卫星）、Google 路网（China 区域）
  -- Google 卫星（lyrs=s）真实 WGS-84，不转
  IF map_url ILIKE '%autonavi%'
     OR (map_url ILIKE '%google.com%' AND map_url NOT ILIKE '%lyrs=s%') THEN
    RETURN wgs84_to_gcj02_lat(lat, lng);
  END IF;
  RETURN lat;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION lng_for_map(map_url TEXT, lat DOUBLE PRECISION, lng DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
BEGIN
  -- 仅识别下拉框里的 GCJ-02 来源：高德（autonavi 含路网+卫星）、Google 路网（China 区域）
  -- Google 卫星（lyrs=s）真实 WGS-84，不转
  IF map_url ILIKE '%autonavi%'
     OR (map_url ILIKE '%google.com%' AND map_url NOT ILIKE '%lyrs=s%') THEN
    RETURN wgs84_to_gcj02_lng(lat, lng);
  END IF;
  RETURN lng;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- ----------------------------------------------------------------------------
-- 自检（可选）：北京天安门 WGS-84 → GCJ-02 应得 ~ (39.91524, 116.40391)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  test_lat DOUBLE PRECISION;
  test_lng DOUBLE PRECISION;
BEGIN
  test_lat := wgs84_to_gcj02_lat(39.913818, 116.397828);
  test_lng := wgs84_to_gcj02_lng(39.913818, 116.397828);
  IF abs(test_lat - 39.91524) > 0.001 OR abs(test_lng - 116.40391) > 0.001 THEN
    RAISE WARNING '坐标转换函数自检异常: 期望 ~(39.91524, 116.40391), 实际 (%, %)', test_lat, test_lng;
  ELSE
    RAISE NOTICE '坐标转换函数安装成功 (天安门测试通过): (%, %)', round(test_lat::numeric, 5), round(test_lng::numeric, 5);
  END IF;
END $$;
