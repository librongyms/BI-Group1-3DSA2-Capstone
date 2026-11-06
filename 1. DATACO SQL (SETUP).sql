-- =====================================================================
SET SQL_SAFE_UPDATES = 0; 
DROP DATABASE IF EXISTS dataco;
CREATE DATABASE dataco CHARACTER SET utf8mb4;
USE dataco;
-- ---------------------------------------------------------------------
-- 1. loading raw file (one column per csv column)
-- ---------------------------------------------------------------------
CREATE TABLE raw_orders (
  type_ VARCHAR(20), days_real INT, days_scheduled INT, benefit_per_order DECIMAL(12,4), sales_per_customer DECIMAL(12,4),
  delivery_status VARCHAR(30), late_delivery_risk TINYINT, category_id INT, category_name VARCHAR(60),
  customer_city VARCHAR(60), customer_country VARCHAR(30), customer_email VARCHAR(30), customer_fname VARCHAR(40),
  customer_id INT, customer_lname VARCHAR(40), customer_password VARCHAR(30), customer_segment VARCHAR(20),
  customer_state VARCHAR(10), customer_street VARCHAR(100), customer_zipcode VARCHAR(10), department_id INT,
  department_name VARCHAR(40), latitude DECIMAL(12,8), longitude DECIMAL(12,8), market VARCHAR(20),
  order_city VARCHAR(60), order_country VARCHAR(60), order_customer_id INT, order_date_raw VARCHAR(20), order_id INT,
  order_item_cardprod_id INT, order_item_discount DECIMAL(12,4), order_item_discount_rate DECIMAL(6,4),
  order_item_id INT, order_item_product_price DECIMAL(12,4), order_item_profit_ratio DECIMAL(6,4),
  order_item_quantity INT, sales DECIMAL(12,4), order_item_total DECIMAL(12,4), order_profit_per_order DECIMAL(12,4),
  order_region VARCHAR(30), order_state VARCHAR(60), order_status VARCHAR(20), order_zipcode VARCHAR(10),
  product_card_id INT, product_category_id INT, product_description VARCHAR(10), product_image VARCHAR(200),
  product_name VARCHAR(100), product_price DECIMAL(12,4), product_status TINYINT, ship_date_raw VARCHAR(20),
  shipping_mode VARCHAR(20)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/DataCoSupplyChainDataset.csv'   
INTO TABLE raw_orders CHARACTER SET latin1
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- (180519 rows dapat)
SELECT COUNT(*) AS order_rows FROM raw_orders;

-- parse dates 
ALTER TABLE raw_orders ADD order_dt DATETIME, ADD ship_dt DATETIME;
UPDATE raw_orders SET order_dt = STR_TO_DATE(order_date_raw, '%c/%e/%Y %H:%i'),
                      ship_dt  = STR_TO_DATE(ship_date_raw,  '%c/%e/%Y %H:%i');

-- index
CREATE INDEX ix_raw_order ON raw_orders (order_id);
CREATE INDEX ix_raw_customer ON raw_orders (customer_id);

-- ---------------------------------------------------------------------
-- 2. calendar 
-- ---------------------------------------------------------------------
SET SESSION cte_max_recursion_depth = 5000;  -- calendar = 1,133 days (limit = 1,000)
CREATE TABLE dim_date (
  date_key DATE PRIMARY KEY, year_ SMALLINT, quarter_ TINYINT, month_ TINYINT, month_name CHAR(3),
  day_ TINYINT, weekday_name CHAR(3), is_weekend TINYINT
);
INSERT INTO dim_date
WITH RECURSIVE d AS (
  SELECT DATE('2015-01-01') AS dt
  UNION ALL SELECT dt + INTERVAL 1 DAY FROM d WHERE dt < '2018-02-06'
)
SELECT dt, YEAR(dt), QUARTER(dt), MONTH(dt), DATE_FORMAT(dt, '%b'), DAY(dt), DATE_FORMAT(dt, '%a'),
       DAYOFWEEK(dt) IN (1, 7)
FROM d;

CREATE TABLE dim_hour (hour_key TINYINT PRIMARY KEY, day_part VARCHAR(10));
INSERT INTO dim_hour
WITH RECURSIVE h AS (SELECT 0 AS hr UNION ALL SELECT hr + 1 FROM h WHERE hr < 23)
SELECT hr, CASE WHEN hr < 6 THEN 'Night' WHEN hr < 12 THEN 'Morning' WHEN hr < 18 THEN 'Afternoon' ELSE 'Evening' END
FROM h;

-- ---------------------------------------------------------------------
-- 3. product: department <- category <- product
-- ---------------------------------------------------------------------
CREATE TABLE dim_department (department_id INT PRIMARY KEY, department_name VARCHAR(40));
INSERT INTO dim_department SELECT DISTINCT department_id, department_name FROM raw_orders;

CREATE TABLE dim_category (
  category_id INT PRIMARY KEY, category_name VARCHAR(60), department_id INT,
  FOREIGN KEY (department_id) REFERENCES dim_department(department_id)
);
INSERT INTO dim_category SELECT DISTINCT category_id, category_name, department_id FROM raw_orders;

CREATE TABLE dim_product (
  product_card_id INT PRIMARY KEY, product_name VARCHAR(100), product_price DECIMAL(12,4),
  product_image VARCHAR(200), category_id INT,
  FOREIGN KEY (category_id) REFERENCES dim_category(category_id)
);
INSERT INTO dim_product
SELECT DISTINCT product_card_id, TRIM(product_name), product_price, TRIM(product_image), category_id FROM raw_orders;

-- ---------------------------------------------------------------------
-- 4. customer geography: country <- state <- city <- customer, segment
-- ---------------------------------------------------------------------
CREATE TABLE dim_customer_country (
  customer_country_key INT AUTO_INCREMENT PRIMARY KEY, customer_country VARCHAR(30) UNIQUE
);
INSERT INTO dim_customer_country (customer_country) SELECT DISTINCT customer_country FROM raw_orders;

CREATE TABLE dim_customer_state (
  customer_state_key INT AUTO_INCREMENT PRIMARY KEY, customer_state VARCHAR(10) UNIQUE, customer_country_key INT,
  FOREIGN KEY (customer_country_key) REFERENCES dim_customer_country(customer_country_key)
);
INSERT INTO dim_customer_state (customer_state, customer_country_key)
SELECT DISTINCT r.customer_state, c.customer_country_key
FROM raw_orders r JOIN dim_customer_country c ON c.customer_country = r.customer_country;

CREATE TABLE dim_customer_city (
  customer_city_key INT AUTO_INCREMENT PRIMARY KEY, customer_city VARCHAR(60), customer_state_key INT,
  UNIQUE (customer_state_key, customer_city),
  FOREIGN KEY (customer_state_key) REFERENCES dim_customer_state(customer_state_key)
);
INSERT INTO dim_customer_city (customer_city, customer_state_key)
SELECT DISTINCT r.customer_city, s.customer_state_key
FROM raw_orders r JOIN dim_customer_state s ON s.customer_state = r.customer_state;

CREATE TABLE dim_customer_segment (segment_key INT AUTO_INCREMENT PRIMARY KEY, customer_segment VARCHAR(20) UNIQUE);
INSERT INTO dim_customer_segment (customer_segment) SELECT DISTINCT customer_segment FROM raw_orders;

CREATE TABLE dim_customer (
  customer_id INT PRIMARY KEY, first_name VARCHAR(40), last_name VARCHAR(40), street VARCHAR(100),
  zipcode VARCHAR(10), latitude DECIMAL(12,8), longitude DECIMAL(12,8), segment_key INT, customer_city_key INT,
  FOREIGN KEY (segment_key) REFERENCES dim_customer_segment(segment_key),
  FOREIGN KEY (customer_city_key) REFERENCES dim_customer_city(customer_city_key)
);
INSERT INTO dim_customer
SELECT r.customer_id, MIN(r.customer_fname), MIN(NULLIF(r.customer_lname, '')), MIN(r.customer_street),
       MIN(NULLIF(r.customer_zipcode, '')), MIN(r.latitude), MIN(r.longitude), MIN(g.segment_key), MIN(ci.customer_city_key)
FROM raw_orders r
JOIN dim_customer_segment g ON g.customer_segment = r.customer_segment
JOIN dim_customer_state s ON s.customer_state = r.customer_state
JOIN dim_customer_city ci ON ci.customer_state_key = s.customer_state_key AND ci.customer_city = r.customer_city
GROUP BY r.customer_id;

-- ---------------------------------------------------------------------
-- 5. Order dest.: market <- region <- state -> country; state <- city
-- ---------------------------------------------------------------------
CREATE TABLE dim_market (market_key INT AUTO_INCREMENT PRIMARY KEY, market VARCHAR(20) UNIQUE);
INSERT INTO dim_market (market) SELECT DISTINCT market FROM raw_orders;

CREATE TABLE dim_order_region (
  region_key INT AUTO_INCREMENT PRIMARY KEY, order_region VARCHAR(30) UNIQUE, market_key INT,
  FOREIGN KEY (market_key) REFERENCES dim_market(market_key)
);
INSERT INTO dim_order_region (order_region, market_key)
SELECT DISTINCT r.order_region, m.market_key FROM raw_orders r JOIN dim_market m ON m.market = r.market;

CREATE TABLE dim_order_country (order_country_key INT AUTO_INCREMENT PRIMARY KEY, order_country VARCHAR(60) UNIQUE);
INSERT INTO dim_order_country (order_country) SELECT DISTINCT order_country FROM raw_orders;

CREATE TABLE dim_order_state (
  order_state_key INT AUTO_INCREMENT PRIMARY KEY, order_state VARCHAR(60), order_country_key INT, region_key INT,
  UNIQUE (order_country_key, order_state),
  FOREIGN KEY (order_country_key) REFERENCES dim_order_country(order_country_key),
  FOREIGN KEY (region_key) REFERENCES dim_order_region(region_key)
);
INSERT INTO dim_order_state (order_state, order_country_key, region_key)
SELECT DISTINCT r.order_state, c.order_country_key, g.region_key
FROM raw_orders r
JOIN dim_order_country c ON c.order_country = r.order_country
JOIN dim_order_region g ON g.order_region = r.order_region;

CREATE TABLE dim_order_city (
  order_city_key INT AUTO_INCREMENT PRIMARY KEY, order_city VARCHAR(60), order_state_key INT,
  UNIQUE (order_state_key, order_city),
  FOREIGN KEY (order_state_key) REFERENCES dim_order_state(order_state_key)
);
INSERT INTO dim_order_city (order_city, order_state_key)
SELECT DISTINCT r.order_city, s.order_state_key
FROM raw_orders r
JOIN dim_order_country c ON c.order_country = r.order_country
JOIN dim_order_state s ON s.order_country_key = c.order_country_key AND s.order_state = r.order_state;

-- ---------------------------------------------------------------------
-- 6. order attribute lookups and order table
-- ---------------------------------------------------------------------
CREATE TABLE dim_shipping_mode (shipping_mode_key INT AUTO_INCREMENT PRIMARY KEY, shipping_mode VARCHAR(20) UNIQUE);
INSERT INTO dim_shipping_mode (shipping_mode) SELECT DISTINCT shipping_mode FROM raw_orders;

CREATE TABLE dim_order_status (order_status_key INT AUTO_INCREMENT PRIMARY KEY, order_status VARCHAR(20) UNIQUE);
INSERT INTO dim_order_status (order_status) SELECT DISTINCT order_status FROM raw_orders;

CREATE TABLE dim_delivery_status (delivery_status_key INT AUTO_INCREMENT PRIMARY KEY, delivery_status VARCHAR(30) UNIQUE);
INSERT INTO dim_delivery_status (delivery_status) SELECT DISTINCT delivery_status FROM raw_orders;

CREATE TABLE dim_payment_type (payment_type_key INT AUTO_INCREMENT PRIMARY KEY, payment_type VARCHAR(20) UNIQUE);
INSERT INTO dim_payment_type (payment_type) SELECT DISTINCT type_ FROM raw_orders;

CREATE TABLE dim_order (
  order_id INT PRIMARY KEY, order_datetime DATETIME, ship_datetime DATETIME, ship_date_key DATE,
  days_shipping_real INT, days_shipping_scheduled INT, late_delivery_risk TINYINT,
  shipping_mode_key INT, order_status_key INT, delivery_status_key INT, payment_type_key INT, order_city_key INT,
  FOREIGN KEY (ship_date_key) REFERENCES dim_date(date_key),
  FOREIGN KEY (shipping_mode_key) REFERENCES dim_shipping_mode(shipping_mode_key),
  FOREIGN KEY (order_status_key) REFERENCES dim_order_status(order_status_key),
  FOREIGN KEY (delivery_status_key) REFERENCES dim_delivery_status(delivery_status_key),
  FOREIGN KEY (payment_type_key) REFERENCES dim_payment_type(payment_type_key),
  FOREIGN KEY (order_city_key) REFERENCES dim_order_city(order_city_key)
);
INSERT INTO dim_order
SELECT r.order_id, MIN(r.order_dt), MIN(r.ship_dt), DATE(MIN(r.ship_dt)), MIN(r.days_real), MIN(r.days_scheduled),
       MIN(r.late_delivery_risk), MIN(sm.shipping_mode_key), MIN(os.order_status_key), MIN(ds.delivery_status_key),
       MIN(pt.payment_type_key), MIN(oc.order_city_key)
FROM raw_orders r
JOIN dim_shipping_mode sm ON sm.shipping_mode = r.shipping_mode
JOIN dim_order_status os ON os.order_status = r.order_status
JOIN dim_delivery_status ds ON ds.delivery_status = r.delivery_status
JOIN dim_payment_type pt ON pt.payment_type = r.type_
JOIN dim_order_country c ON c.order_country = r.order_country
JOIN dim_order_state s ON s.order_country_key = c.order_country_key AND s.order_state = r.order_state
JOIN dim_order_city oc ON oc.order_state_key = s.order_state_key AND oc.order_city = r.order_city
GROUP BY r.order_id;

-- ---------------------------------------------------------------------
-- 7. fact order items
-- ---------------------------------------------------------------------
CREATE TABLE fact_order_items (
  order_item_id INT PRIMARY KEY, order_id INT, customer_id INT, product_card_id INT,
  order_date_key DATE, order_hour TINYINT,
  quantity INT, product_price DECIMAL(12,4), sales DECIMAL(12,4), discount DECIMAL(12,4), discount_rate DECIMAL(6,4),
  order_item_total DECIMAL(12,4), profit DECIMAL(12,4), profit_ratio DECIMAL(6,4),
  FOREIGN KEY (order_id) REFERENCES dim_order(order_id),
  FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
  FOREIGN KEY (product_card_id) REFERENCES dim_product(product_card_id),
  FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
  FOREIGN KEY (order_hour) REFERENCES dim_hour(hour_key)
);
INSERT INTO fact_order_items
SELECT order_item_id, order_id, customer_id, product_card_id, DATE(order_dt), HOUR(order_dt),
       order_item_quantity, order_item_product_price, sales, order_item_discount, order_item_discount_rate,
       order_item_total, benefit_per_order, order_item_profit_ratio
FROM raw_orders;


-- ---------------------------------------------------------------------
-- 8. exact row count of all tables
-- ---------------------------------------------------------------------
SELECT 'fact_order_items' AS table_name, COUNT(*) AS row_count FROM fact_order_items
UNION ALL SELECT 'dim_order' AS table_name, COUNT(*) AS row_count FROM dim_order
UNION ALL SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM dim_customer
UNION ALL SELECT 'dim_customer_segment' AS table_name, COUNT(*) AS row_count FROM dim_customer_segment
UNION ALL SELECT 'dim_customer_city' AS table_name, COUNT(*) AS row_count FROM dim_customer_city
UNION ALL SELECT 'dim_customer_state' AS table_name, COUNT(*) AS row_count FROM dim_customer_state
UNION ALL SELECT 'dim_customer_country' AS table_name, COUNT(*) AS row_count FROM dim_customer_country
UNION ALL SELECT 'dim_product' AS table_name, COUNT(*) AS row_count FROM dim_product
UNION ALL SELECT 'dim_category' AS table_name, COUNT(*) AS row_count FROM dim_category
UNION ALL SELECT 'dim_department' AS table_name, COUNT(*) AS row_count FROM dim_department
UNION ALL SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dim_date
UNION ALL SELECT 'dim_hour' AS table_name, COUNT(*) AS row_count FROM dim_hour
UNION ALL SELECT 'dim_shipping_mode' AS table_name, COUNT(*) AS row_count FROM dim_shipping_mode
UNION ALL SELECT 'dim_order_status' AS table_name, COUNT(*) AS row_count FROM dim_order_status
UNION ALL SELECT 'dim_delivery_status' AS table_name, COUNT(*) AS row_count FROM dim_delivery_status
UNION ALL SELECT 'dim_payment_type' AS table_name, COUNT(*) AS row_count FROM dim_payment_type
UNION ALL SELECT 'dim_order_city' AS table_name, COUNT(*) AS row_count FROM dim_order_city
UNION ALL SELECT 'dim_order_state' AS table_name, COUNT(*) AS row_count FROM dim_order_state
UNION ALL SELECT 'dim_order_country' AS table_name, COUNT(*) AS row_count FROM dim_order_country
UNION ALL SELECT 'dim_order_region' AS table_name, COUNT(*) AS row_count FROM dim_order_region
UNION ALL SELECT 'dim_market' AS table_name, COUNT(*) AS row_count FROM dim_market;

-- count = 21
SELECT COUNT(*) AS foreign_keys FROM information_schema.referential_constraints WHERE constraint_schema = 'dataco';

-- =========================================================================================================
-- DROP TABLE raw_orders;
SELECT * FROM dim_order_state;

SELECT order_country FROM dim_order_country ORDER BY order_country;
