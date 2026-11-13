-- =====================================================
-- PROJECT: TARGET E-COMMERCE DATA ANALYSIS
-- CREATED BY: MATHIHA AMREEN M U
-- TOOL: GOOGLE BIGQUERY
-- NOTE: Review the dataset/table names against your BigQuery
-- project before running. Queries have been reformatted and
-- obvious syntax issues in the supplied text have been repaired.
-- =====================================================

-- QUERY 01
-- Business question: What are the data types of all columns
-- in the customers table?
-- Assumption: The dataset is named Target and the table is
-- named customers csv.
SELECT
  column_name,
  data_type
FROM `Target.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'customers csv'
ORDER BY ordinal_position;


-- QUERY 02
-- Business question: What is the time range during which
-- orders were placed?
SELECT
  MIN(order_purchase_timestamp) AS first_order_timestamp,
  MAX(order_purchase_timestamp) AS last_order_timestamp
FROM `Target.orders csv`;


-- QUERY 03
-- Business question: How many unique customer cities and
-- states are represented among customers who placed orders?
SELECT
  COUNT(DISTINCT c.customer_city) AS city_count,
  COUNT(DISTINCT c.customer_state) AS state_count
FROM `Target.customers csv` AS c
JOIN `Target.orders csv` AS o
  ON c.customer_id = o.customer_id;


-- QUERY 04
-- Business question: Is there a growing trend in the number
-- of orders placed over the years, month by month?
SELECT
  EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
  EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
  FORMAT_TIMESTAMP('%B', order_purchase_timestamp) AS month_name,
  COUNT(*) AS order_count
FROM `Target.orders csv`
GROUP BY order_year, order_month, month_name
ORDER BY order_year, order_month;


-- QUERY 05
-- Business question: Is there monthly seasonality in the
-- number of orders placed?
SELECT
  EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
  FORMAT_TIMESTAMP('%B', order_purchase_timestamp) AS month_name,
  COUNT(*) AS order_count
FROM `Target.orders csv`
GROUP BY order_month, month_name
ORDER BY order_count DESC;


-- QUERY 06
-- Business question: During what time of day do Brazilian
-- customers mostly place their orders?
-- Time brackets: 0-6 Dawn; 7-12 Morning; 13-18 Afternoon;
-- 19-23 Night.
-- Note: This query counts orders by hour bracket. To restrict
-- the analysis to Brazilian customers, a country field/table
-- must be available and joined to the orders/customers data.
SELECT
  CASE
    WHEN EXTRACT(HOUR FROM o.order_purchase_timestamp) BETWEEN 0 AND 6 THEN 'Dawn'
    WHEN EXTRACT(HOUR FROM o.order_purchase_timestamp) BETWEEN 7 AND 12 THEN 'Morning'
    WHEN EXTRACT(HOUR FROM o.order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'Afternoon'
    WHEN EXTRACT(HOUR FROM o.order_purchase_timestamp) BETWEEN 19 AND 23 THEN 'Night'
  END AS time_of_day,
  COUNT(o.order_id) AS total_orders
FROM `Target.orders csv` AS o
GROUP BY time_of_day
ORDER BY total_orders DESC;


-- QUERY 07
-- Business question: What is the month-by-month number of
-- orders placed in each customer state?
SELECT
  c.customer_state,
  EXTRACT(MONTH FROM o.order_purchase_timestamp) AS order_month,
  COUNT(o.order_id) AS number_of_orders
FROM `Target.customers csv` AS c
JOIN `Target.orders csv` AS o
  ON c.customer_id = o.customer_id
GROUP BY c.customer_state, order_month
ORDER BY c.customer_state, order_month;


-- QUERY 08
-- Business question: How are customers distributed across
-- the states?
SELECT
  customer_state,
  COUNT(DISTINCT customer_id) AS number_of_customers
FROM `Target.customers csv`
GROUP BY customer_state
ORDER BY number_of_customers DESC;


-- QUERY 09
-- Business question: What is the year-over-year percentage
-- difference in payment value for January-August 2018 vs 2017?
WITH yearly_payment AS (
  SELECT
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
    SUM(p.payment_value) AS total_payment
  FROM `Target.orders csv` AS o
  JOIN `Target.payments` AS p
    ON o.order_id = p.order_id
  WHERE EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
    AND EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
  GROUP BY order_year
),
previous_payment AS (
  SELECT
    order_year,
    total_payment,
    LAG(total_payment) OVER (ORDER BY order_year) AS previous_year_payment
  FROM yearly_payment
)
SELECT
  order_year,
  total_payment,
  previous_year_payment,
  SAFE_DIVIDE(total_payment - previous_year_payment, previous_year_payment) * 100
    AS percentage_difference
FROM previous_payment
WHERE order_year = 2018;


-- QUERY 10
-- Business question: What are the total and average order
-- item prices for each seller state?
SELECT
  s.seller_state,
  SUM(oi.price) AS total_value,
  AVG(oi.price) AS average_value
FROM `Target.order items` AS oi
JOIN `Target.sellers` AS s
  ON oi.seller_id = s.seller_id
GROUP BY s.seller_state
ORDER BY s.seller_state;


-- QUERY 11
-- Business question: What are the total and average freight
-- values for each seller state?
SELECT
  s.seller_state,
  SUM(oi.freight_value) AS total_freight_value,
  AVG(oi.freight_value) AS average_freight_value
FROM `Target.order items` AS oi
JOIN `Target.sellers` AS s
  ON oi.seller_id = s.seller_id
GROUP BY s.seller_state
ORDER BY s.seller_state;


-- QUERY 12
-- Business question: How many days does each order take to
-- deliver, and how does actual delivery compare with the
-- estimated delivery date?
SELECT
  order_id,
  DATE_DIFF(
    DATE(order_delivered_customer_date),
    DATE(order_purchase_timestamp),
    DAY
  ) AS time_to_deliver_days,
  DATE_DIFF(
    DATE(order_estimated_delivery_date),
    DATE(order_delivered_customer_date),
    DAY
  ) AS difference_estimated_vs_actual_days
FROM `Target.orders csv`
WHERE order_delivered_customer_date IS NOT NULL;


-- QUERY 13
-- Business question: Which five seller states have the
-- highest and lowest average freight values?
WITH state_freight AS (
  SELECT
    s.seller_state,
    ROUND(AVG(oi.freight_value), 2) AS average_freight
  FROM `Target.sellers` AS s
  JOIN `Target.order items` AS oi
    ON s.seller_id = oi.seller_id
  GROUP BY s.seller_state
),
highest_five AS (
  SELECT
    seller_state,
    average_freight,
    ROW_NUMBER() OVER (ORDER BY average_freight DESC) AS row_num
  FROM state_freight
),
lowest_five AS (
  SELECT
    seller_state,
    average_freight,
    ROW_NUMBER() OVER (ORDER BY average_freight ASC) AS row_num
  FROM state_freight
)
SELECT
  h.seller_state AS highest_freight_state,
  h.average_freight AS highest_average_freight,
  l.seller_state AS lowest_freight_state,
  l.average_freight AS lowest_average_freight
FROM highest_five AS h
JOIN lowest_five AS l
  ON h.row_num = l.row_num
WHERE h.row_num <= 5
ORDER BY h.row_num;


-- QUERY 14
-- Business question: Which five customer states have the
-- highest and lowest average delivery time?
WITH state_delivery AS (
  SELECT
    c.customer_state,
    ROUND(AVG(DATE_DIFF(
      DATE(o.order_delivered_customer_date),
      DATE(o.order_purchase_timestamp),
      DAY
    )), 2) AS average_delivery_time
  FROM `Target.customers csv` AS c
  JOIN `Target.orders csv` AS o
    ON c.customer_id = o.customer_id
  WHERE o.order_delivered_customer_date IS NOT NULL
  GROUP BY c.customer_state
),
highest_five AS (
  SELECT
    customer_state,
    average_delivery_time,
    ROW_NUMBER() OVER (ORDER BY average_delivery_time DESC) AS row_num
  FROM state_delivery
),
lowest_five AS (
  SELECT
    customer_state,
    average_delivery_time,
    ROW_NUMBER() OVER (ORDER BY average_delivery_time ASC) AS row_num
  FROM state_delivery
)
SELECT
  h.customer_state AS highest_delivery_time_state,
  h.average_delivery_time AS highest_average_delivery_days,
  l.customer_state AS lowest_delivery_time_state,
  l.average_delivery_time AS lowest_average_delivery_days
FROM highest_five AS h
JOIN lowest_five AS l
  ON h.row_num = l.row_num
WHERE h.row_num <= 5
ORDER BY h.row_num;


-- QUERY 15
-- Business question: Which five customer states receive
-- orders fastest compared with the estimated delivery date?
-- Positive values mean delivery occurred before the estimate.
SELECT
  c.customer_state,
  FLOOR(AVG(DATE_DIFF(
    DATE(o.order_estimated_delivery_date),
    DATE(o.order_delivered_customer_date),
    DAY
  ))) AS average_days_earlier_than_estimate
FROM `Target.customers csv` AS c
JOIN `Target.orders csv` AS o
  ON c.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY average_days_earlier_than_estimate DESC
LIMIT 5;


-- QUERY 16
-- Business question: What is the month-by-month number of
-- orders placed using each payment type?
SELECT
  EXTRACT(MONTH FROM o.order_purchase_timestamp) AS order_month,
  EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
  p.payment_type,
  COUNT(DISTINCT p.order_id) AS number_of_orders
FROM `Target.orders csv` AS o
JOIN `Target.payments` AS p
  ON o.order_id = p.order_id
GROUP BY order_month, order_year, p.payment_type
ORDER BY order_year, order_month, p.payment_type;


-- QUERY 17
-- Business question: How many orders are associated with
-- each number of payment installments?
SELECT
  payment_installments,
  COUNT(DISTINCT order_id) AS number_of_orders
FROM `Target.payments`
WHERE payment_installments >= 1
GROUP BY payment_installments
ORDER BY payment_installments;
