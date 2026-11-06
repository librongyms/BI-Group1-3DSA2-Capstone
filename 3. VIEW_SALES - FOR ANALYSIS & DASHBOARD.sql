USE dataco;
CREATE OR REPLACE VIEW v_sales AS
SELECT f.order_item_id, f.order_id, f.order_date_key AS order_date, d.year_ AS order_year, d.month_name AS order_month,
       h.day_part AS order_day_part,
       f.quantity, f.sales, f.discount, f.order_item_total AS net_sales, f.profit,
       p.product_name, cat.category_name, dep.department_name,
       cs.customer_segment, cci.customer_city, cst.customer_state,
       sm.shipping_mode, os.order_status, ds.delivery_status, pt.payment_type,
       o.days_shipping_real, o.days_shipping_scheduled, o.late_delivery_risk,
       oci.order_city, ost.order_state, oco.order_country, r.order_region, m.market
FROM fact_order_items f
JOIN dim_date d              ON d.date_key = f.order_date_key
JOIN dim_hour h              ON h.hour_key = f.order_hour
JOIN dim_product p           ON p.product_card_id = f.product_card_id
JOIN dim_category cat        ON cat.category_id = p.category_id
JOIN dim_department dep      ON dep.department_id = cat.department_id
JOIN dim_customer c          ON c.customer_id = f.customer_id
JOIN dim_customer_segment cs ON cs.segment_key = c.segment_key
JOIN dim_customer_city cci   ON cci.customer_city_key = c.customer_city_key
JOIN dim_customer_state cst  ON cst.customer_state_key = cci.customer_state_key
JOIN dim_order o             ON o.order_id = f.order_id
JOIN dim_shipping_mode sm    ON sm.shipping_mode_key = o.shipping_mode_key
JOIN dim_order_status os     ON os.order_status_key = o.order_status_key
JOIN dim_delivery_status ds  ON ds.delivery_status_key = o.delivery_status_key
JOIN dim_payment_type pt     ON pt.payment_type_key = o.payment_type_key
JOIN dim_order_city oci      ON oci.order_city_key = o.order_city_key
JOIN dim_order_state ost     ON ost.order_state_key = oci.order_state_key
JOIN dim_order_country oco   ON oco.order_country_key = ost.order_country_key
JOIN dim_order_region r      ON r.region_key = ost.region_key
JOIN dim_market m            ON m.market_key = r.market_key;

SELECT * FROM v_sales LIMIT 10;
SELECT COUNT(*) FROM v_sales;
SELECT COUNT(*) AS order_lines, COUNT(DISTINCT order_id) AS orders FROM v_sales;