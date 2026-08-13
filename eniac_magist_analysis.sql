-- =========================================================
-- ENIAC–MAGIST PARTNERSHIP ANALYSIS
-- SQL BUSINESS EXPLORATION
-- =========================================================
-- Purpose:
-- Evaluate whether Magist is a suitable distribution partner
-- for Eniac, with a focus on Tech product performance,
-- premium-product demand, seller structure, and delivery speed.
--
-- Tech categories used consistently throughout this analysis:
--   telephony
--   tablets_printing_image
--   computers
--   computers_accessories
--   audio
--   electronics
--   consoles_games
--   pc_gamer
-- =========================================================

USE magist;


-- =========================================================
-- 1. PRODUCT PRICE POSITIONING
-- Do they sell more expensive or lower-priced products?
-- =========================================================

SELECT
    CASE
        WHEN product_category_name_english IN (
            'telephony',
            'tablets_printing_image',
            'computers',
            'computers_accessories',
            'audio',
            'electronics',
            'consoles_games',
            'pc_gamer'
        )
        THEN 'Tech'
        ELSE 'Other'
    END AS category_group,

    CASE
        WHEN order_items.price > (
            SELECT AVG(price)
            FROM order_items
        )
        THEN 'Expensive'
        ELSE 'Not Expensive'
    END AS price_group,

    COUNT(*) AS products_sold

FROM products
JOIN product_category_name_translation
    ON products.product_category_name =
       product_category_name_translation.product_category_name
JOIN order_items
    ON products.product_id = order_items.product_id

GROUP BY
    category_group,
    price_group;

-- Conclusion:
-- Magist sells more non-expensive products than expensive products,
-- both in Tech and in Other categories.


-- =========================================================
-- 2. DATASET CATEGORY OVERVIEW
-- How many product categories are available?
-- =========================================================

SELECT
    COUNT(product_category_name) AS number_of_categories
FROM product_category_name_translation;

-- Result:
-- 75 categories in total.
-- 8 categories are classified as Tech in this analysis.
-- 67 categories are classified as Other / Non-Tech.


-- =========================================================
-- 3. ITEMS SOLD PER CATEGORY
-- How strongly is each category represented in overall sales?
-- =========================================================

SELECT
    product_category_name_translation.product_category_name_english AS category,
    COUNT(*) AS items_sold,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percent_of_all_sales

FROM products
JOIN product_category_name_translation
    ON products.product_category_name =
       product_category_name_translation.product_category_name
JOIN order_items
    ON products.product_id = order_items.product_id

GROUP BY
    product_category_name_translation.product_category_name_english

ORDER BY
    items_sold DESC;

-- Observations:
-- bed_bath_table, health_beauty, sports_leisure, and furniture_decor
-- are among the strongest-selling categories.
--
-- computers_accessories performs strongly among Tech categories.
-- telephony also shows relevant sales volume.
-- electronics performs at a lower level.
-- computers and pc_gamer show very low sales volume.
--
-- Business interpretation:
-- Magist appears more suitable for accessories and telephony than
-- for large computers or specialized gaming hardware.


-- =========================================================
-- 4. SELLER INCOME
-- Compare average monthly income of all sellers vs Tech sellers.
-- =========================================================

WITH tech_sellers AS (

    SELECT DISTINCT
        order_items.seller_id

    FROM order_items
    JOIN orders
        ON order_items.order_id = orders.order_id
    JOIN products
        ON order_items.product_id = products.product_id
    JOIN product_category_name_translation
        ON products.product_category_name =
           product_category_name_translation.product_category_name

    WHERE orders.order_status = 'delivered'
      AND product_category_name_english IN (
          'telephony',
          'tablets_printing_image',
          'computers',
          'computers_accessories',
          'audio',
          'electronics',
          'consoles_games',
          'pc_gamer'
      )
),

months AS (

    SELECT
        COUNT(
            DISTINCT DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
        ) AS number_of_months

    FROM orders
    WHERE order_status = 'delivered'
),

all_sellers_income AS (

    SELECT
        SUM(order_items.price) AS total_income

    FROM order_items
    JOIN orders
        ON order_items.order_id = orders.order_id

    WHERE orders.order_status = 'delivered'
),

tech_sellers_income AS (

    SELECT
        SUM(order_items.price) AS total_income

    FROM order_items
    JOIN orders
        ON order_items.order_id = orders.order_id
    JOIN tech_sellers
        ON order_items.seller_id = tech_sellers.seller_id

    WHERE orders.order_status = 'delivered'
)

SELECT
    'All Sellers' AS seller_group,
    ROUND(all_sellers_income.total_income, 2) AS total_income,
    months.number_of_months,
    ROUND(
        all_sellers_income.total_income / months.number_of_months,
        2
    ) AS avg_monthly_income

FROM all_sellers_income
CROSS JOIN months

UNION ALL

SELECT
    'Tech Sellers' AS seller_group,
    ROUND(tech_sellers_income.total_income, 2) AS total_income,
    months.number_of_months,
    ROUND(
        tech_sellers_income.total_income / months.number_of_months,
        2
    ) AS avg_monthly_income

FROM tech_sellers_income
CROSS JOIN months;


-- =========================================================
-- 5. AVERAGE DELIVERY TIME
-- How long does delivery take on average?
-- =========================================================

SELECT
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        )
    ) AS avg_delivery_days

FROM orders;


-- =========================================================
-- 6. TECH VS TOP NON-TECH CATEGORIES BY REVENUE
-- How do Tech categories compare with Magist's strongest
-- Non-Tech categories?
-- =========================================================

SELECT
    pt.product_category_name_english AS category,
    ROUND(SUM(oi.price), 0) AS revenue,
    'Tech' AS category_type

FROM order_items AS oi
JOIN products AS p
    ON oi.product_id = p.product_id
JOIN product_category_name_translation AS pt
    ON p.product_category_name = pt.product_category_name

WHERE pt.product_category_name_english IN (
    'audio',
    'consoles_games',
    'electronics',
    'computers_accessories',
    'pc_gamer',
    'computers',
    'tablets_printing_image',
    'telephony'
)

GROUP BY
    pt.product_category_name_english

UNION ALL

SELECT
    category,
    revenue,
    'Non-Tech' AS category_type

FROM (
    SELECT
        pt.product_category_name_english AS category,
        ROUND(SUM(oi.price), 0) AS revenue

    FROM order_items AS oi
    JOIN products AS p
        ON oi.product_id = p.product_id
    JOIN product_category_name_translation AS pt
        ON p.product_category_name = pt.product_category_name

    WHERE pt.product_category_name_english NOT IN (
        'audio',
        'consoles_games',
        'electronics',
        'computers_accessories',
        'pc_gamer',
        'computers',
        'tablets_printing_image',
        'telephony'
    )

    GROUP BY
        pt.product_category_name_english

    ORDER BY
        revenue DESC

    LIMIT 8
) AS top_non_tech

ORDER BY
    revenue DESC;


-- =========================================================
-- 7. DELIVERY PROCESS BY DELIVERY STATUS
-- Compare the delivery process for delayed vs on-time orders.
-- =========================================================

SELECT
    CASE
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) > 0
        THEN 'Delayed'
        ELSE 'On Time'
    END AS delivery_status,

    ROUND(
        AVG(
            DATEDIFF(
                order_approved_at,
                order_purchase_timestamp
            )
        ),
        1
    ) AS avg_order_placement_to_approval,

    ROUND(
        AVG(
            DATEDIFF(
                order_delivered_carrier_date,
                order_approved_at
            )
        ),
        1
    ) AS avg_approval_to_carrier,

    ROUND(
        AVG(
            DATEDIFF(
                order_delivered_customer_date,
                order_delivered_carrier_date
            )
        ),
        1
    ) AS avg_carrier_to_customer

FROM orders

GROUP BY
    CASE
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) > 0
        THEN 'Delayed'
        ELSE 'On Time'
    END;


-- =========================================================
-- 8. TOTAL NUMBER OF SELLERS
-- =========================================================

SELECT
    COUNT(DISTINCT seller_id) AS total_sellers
FROM sellers;


-- =========================================================
-- 9. NUMBER OF TECH SELLERS
-- Definition used in the presentation:
-- Any seller associated with at least one Tech product in order_items.
-- =========================================================

SELECT
    COUNT(DISTINCT sellers.seller_id) AS tech_sellers

FROM sellers
INNER JOIN order_items
    ON sellers.seller_id = order_items.seller_id
INNER JOIN products
    ON order_items.product_id = products.product_id
INNER JOIN product_category_name_translation
    ON products.product_category_name =
       product_category_name_translation.product_category_name

WHERE product_category_name_english IN (
    'audio',
    'consoles_games',
    'electronics',
    'computers_accessories',
    'pc_gamer',
    'computers',
    'tablets_printing_image',
    'telephony'
);


-- =========================================================
-- 10. ACTIVE MONTHS PER YEAR
-- How many months of order activity are present in each year?
-- =========================================================

SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    COUNT(
        DISTINCT MONTH(order_purchase_timestamp)
    ) AS months_in_year

FROM orders

GROUP BY
    YEAR(order_purchase_timestamp)

ORDER BY
    order_year;


-- =========================================================
-- 11. NUMBER OF TECH ITEMS SOLD
-- =========================================================

SELECT
    COUNT(*) AS tech_items_sold

FROM order_items
LEFT JOIN products
    ON order_items.product_id = products.product_id
LEFT JOIN product_category_name_translation
    ON products.product_category_name =
       product_category_name_translation.product_category_name

WHERE product_category_name_english IN (
    'audio',
    'consoles_games',
    'electronics',
    'computers_accessories',
    'pc_gamer',
    'computers',
    'tablets_printing_image',
    'telephony'
);


-- =========================================================
-- 12. TOTAL NUMBER OF ORDER ITEMS
-- =========================================================

SELECT
    COUNT(order_item_id) AS total_order_items
FROM order_items;


-- =========================================================
-- END OF ANALYSIS
-- =========================================================
