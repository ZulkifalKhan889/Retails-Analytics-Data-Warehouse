#now here we are gonna to create the curated views for Power BI reporting 

use brazilian_ecommerce_analytics;


#now we are creating our first view first is about sales as it is an imp figure here

CREATE OR REPLACE VIEW vw_sales AS

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,

    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,

    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,

    p.product_category_name,

    c.customer_city,
    c.customer_state

FROM orders o

INNER JOIN customer c
    ON o.customer_id = c.customer_id

INNER JOIN order_items oi
    ON o.order_id = oi.order_id

LEFT JOIN product p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered';

#now we were making view of sales but we selected a lot of tables the reason is it is  not a simple sales qury but rather it is a 
#a data layer and based on this data layer we will be getting other analysis in power bi. 
#the best thing about data layer is we can get other analysis form it in power bi like
#form this same layer we can get

#Which category generated the revenue?
#Which state generated the revenue? etc 

#so basically this view is a dataset where we can answera lot of things from it and we will be using that in our Dashboard
#"Give Power BI one convenient reporting dataset containing the sales transaction plus the dimensions needed to analyze those sales."


#lets display the view we created

SELECT *
FROM vw_sales
LIMIT 10;

#now if we look at the results this view is enough or this data layer to give power bi info about:
#revenue, orders, products, cateogries, sellers, customers, purchase date, freight, deluvery date etc 
#
#lets first validate this view  becuase total rows does not mean total orders as one order can contain multiple items
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS total_customers,
    COUNT(DISTINCT product_id) AS total_products,
    COUNT(DISTINCT seller_id) AS total_sellers
FROM vw_sales;

#now as we discussed this view is at order_item level like sales product cateogry etc 
#but it is not on customer level 

#now we need to create a one on customer level 
#in above 1 row = 1 order item 
 #but here on customer level it would be 
 
 #one rows = 1 unique customer 
 #power bi will directly analyze this custoemr level metrics like from this table without repeatedly building customer calculations 
 #metrics for customer like 
 #total revenue per customer, number of orders, number of items purchased, average order value eetc so all the things or metrics related to the customer
 
 
#  Grain: 1 row per unique customer

CREATE OR REPLACE VIEW vw_customers AS

SELECT
    c.customer_unique_id,

    MAX(c.customer_city) AS customer_city,
    MAX(c.customer_state) AS customer_state,

#the order_id is unique cause one order cna contain several items 
    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(oi.order_item_id) AS total_items,

    SUM(oi.price) AS total_revenue,

    SUM(oi.freight_value) AS total_freight,

    MIN(o.order_purchase_timestamp) AS first_purchase_date,

    MAX(o.order_purchase_timestamp) AS last_purchase_date,

    CASE
        WHEN COUNT(DISTINCT o.order_id) > 1
        THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type

FROM customer c

INNER JOIN orders o
    ON c.customer_id = o.customer_id

INNER JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    c.customer_unique_id;
    
#look here we are joining 3 tables why? becuase each one has a specific job 
#like customers: who is the customer?
# orders:  what orders did they make?
# order_items:   what did they buy and how much they generate 

#lets test it

SELECT *
FROM vw_customers
LIMIT 10;
 
 #lets validate the results
 
 SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,

    SUM(total_orders) AS total_orders,
    SUM(total_items) AS total_items,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    SUM(
        CASE
            WHEN customer_type = 'Repeat Customer'
            THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    SUM(
        CASE
            WHEN customer_type = 'One-Time Customer'
            THEN 1
            ELSE 0
        END
    ) AS one_time_customers

FROM vw_customers;


#next view is about products so power bi will use this table to get and display everthing about the products adn its performance 
# 1 row = 1 product 

#this will answer like how much revenue each product generate? how many units were sold? which category performs best? etc et c



-- PRODUCT ANALYTICS VIEW
-- Grain: 1 row per product


CREATE OR REPLACE VIEW vw_products AS

SELECT
    p.product_id,

	#some products have blank categories so convet blank into null will be easu there in the power bi 
    NULLIF(TRIM(p.product_category_name), '') AS product_category,

    COUNT(oi.order_item_id) AS units_sold,

    COUNT(DISTINCT o.order_id) AS total_orders,

    SUM(oi.price) AS total_revenue,

    SUM(oi.freight_value) AS total_freight,

    AVG(oi.price) AS average_price,

    COUNT(DISTINCT o.customer_id) AS unique_customers

FROM product p

INNER JOIN order_items oi
    ON p.product_id = oi.product_id

INNER JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    p.product_id,
    NULLIF(TRIM(p.product_category_name), '');
    
    
#now lets see why we use these specific tables for joins 
#products: which product
#order_item: how many sold+how much revenue as price is also there in this table
#orders: was the order delievered +which order/customer ?

#lets test the query

SELECT *
FROM vw_products
LIMIT 10;

#lets do the validation

SELECT
    COUNT(*) AS total_products,

    SUM(units_sold) AS total_units_sold,

    SUM(total_orders) AS total_order_product_combinations,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    ROUND(SUM(total_freight), 2) AS total_freight

FROM vw_products;

#so the validation is good

#now next view would be about seller to find out and visulaize thier results 
#it will answer like which seler generate most revenue?
#how many orders each seller handle?
#how many units have they sold etc 

# 1 row = 1 seller here in this below table


-- SELLER ANALYTICS VIEW
-- Grain: 1 row per seller


CREATE OR REPLACE VIEW vw_sellers AS

SELECT
    oi.seller_id,

    COUNT(oi.order_item_id) AS units_sold,

    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,

    SUM(oi.price) AS total_revenue,

    SUM(oi.freight_value) AS total_freight,

    AVG(oi.price) AS average_item_price

FROM order_items oi

INNER JOIN orders o
    ON oi.order_id = o.order_id

INNER JOIN customer c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY
    oi.seller_id; 
    
    
#now here we are not joining the product table here becuase seller performance does not require product attributes for the basic seller view

SELECT *
FROM vw_sellers
LIMIT 10;

#if we look at the 2nd customer here below so  he sold 234 units across 195 distinct orders serving 195 distinct customers 

#lets validate the result

SELECT
    COUNT(*) AS total_sellers,

    SUM(units_sold) AS total_units_sold,

    ROUND(SUM(total_revenue), 2) AS total_revenue,

    ROUND(SUM(total_freight), 2) AS total_freight

FROM vw_sellers;

#so the revnue is good means the anlaysis has no mistake 

#next view or we can say the data layer is about payments 

#1 row = 1 payment

-- ============================================================
-- PAYMENT ANALYTICS VIEW
-- Grain: 1 row per payment record
-- ============================================================

CREATE OR REPLACE VIEW vw_payments AS

SELECT
    op.order_id,

    c.customer_unique_id,

    o.order_purchase_timestamp,

    op.payment_sequential,
    op.payment_type,
    op.payment_installments,
    op.payment_value

FROM payments op

INNER JOIN orders o
    ON op.order_id = o.order_id

INNER JOIN customer c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered';

#so payment is joinnig with orders: when did the order happen 
#customers: who made the payment


SELECT *
FROM vw_payments
LIMIT 10;

#lets validate it and check the overall dataset 

SELECT
    COUNT(*) AS total_payment_records,

    COUNT(DISTINCT order_id) AS total_orders,

    COUNT(DISTINCT customer_unique_id) AS total_customers,

    ROUND(SUM(payment_value), 2) AS total_payment_value

FROM vw_payments;


#now check whether the payment cagtegories behvae sensibly 

SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM vw_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

##
#NExt is delievry 
#1 row = 1 delivery


-- ============================================================
-- DELIVERY ANALYTICS VIEW
-- Grain: 1 row per delivered order
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery AS

SELECT
    o.order_id,

    c.customer_unique_id,

    c.customer_city,
    c.customer_state,

    o.order_purchase_timestamp,
    o.order_estimated_delivery_date,
    o.order_delivered_customer_date,


 #the difference betwen delivered date and purchase date in days 
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp
    ) AS delivery_days,

 #the follwing give us the delivery diff relative to the estimate so 
 #-3  means delivered 3 days early 
 #0 means delivered on estimated date 
 #+5 delivered 5 days late
 
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    ) AS delivery_delay_days,

    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
        THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status

FROM orders o

INNER JOIN customer c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
  
  #now here is the table only for order and customer joins with delivery as delievry is about the order not individual products 


#now lets test the above query 
SELECT *
FROM vw_delivery
LIMIT 10;

#now if we look at the first record then it shows the delivery delay days as -9 so it means the ordered arrived 9 days earlier 
#the reason we put it in numeric becuase its easy for power bi to calculate averages, and trends etc

#lets validate this 

SELECT
    COUNT(*) AS total_delivered_orders,

    COUNT(DISTINCT order_id) AS unique_orders,

    COUNT(DISTINCT customer_unique_id) AS unique_customers,

    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,

    MIN(delivery_days) AS min_delivery_days,

    MAX(delivery_days) AS max_delivery_days,

    ROUND(AVG(delivery_delay_days), 2) AS avg_delivery_delay_days

FROM vw_delivery;

#now lets count the no of delivery that was on time and those which was late
SELECT
    delivery_status,
    COUNT(*) AS orders,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM vw_delivery),
        2
    ) AS percentage
FROM vw_delivery
GROUP BY delivery_status;

#another review would be for review and customer exp 
describe reviews;

#now the review table contains some of the best columsn that can be used to withdraw this insights from it 
#we are not joining prod or order item with it as the review view should not contain the duplicated rows 

#so this review table would be combine with orders table on order_id and with customers on customer id 

CREATE OR REPLACE VIEW vw_reviews AS

SELECT
    r.review_id,
    r.order_id,

    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    o.order_purchase_timestamp,

    r.review_score,
    r.review_comment_title,
    r.review_comment_message,

    r.review_creation_date,
    r.review_answer_timestamp

FROM reviews r
INNER JOIN orders o
    ON r.order_id = o.order_id
INNER JOIN customer c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';

#now this view is based on delivered orderes as reviews are from those orders that are delieverd 

SELECT *
FROM vw_reviews
LIMIT 10;

#now lets validate it if each row represents 1 review or not?

#but here is the case we are taking both the review_id and order_id as they both combines to make a unique_id as review_id is not unique by itself
#we have discussed this earlier 

SELECT
    COUNT(*) AS total_review_records,
    COUNT(DISTINCT CONCAT(review_id, order_id)) AS unique_review_order_records,

    COUNT(DISTINCT order_id) AS reviewed_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,

    MIN(review_score) AS min_score,
    MAX(review_score) AS max_score,
    ROUND(AVG(review_score), 2) AS average_score

FROM vw_reviews;

#so above each row is eactly represent each reviews so we are good till here

### Distribution of reviews 

#this is imp for power bi and could give us a good insights thats why we added this

SELECT
    review_score,
    COUNT(*) AS review_records,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM vw_reviews),
        2
    ) AS percentage
FROM vw_reviews
GROUP BY review_score
ORDER BY review_score;

#now one last reviews which is too important for our analysis vw_monthyly_sales 

#now this will be diff from the others because it will be an aggregate view not a transactional or grain level view.
#it will give power bi  a clean reusable dataset for monthyl revenue, orders, items , customers, and AOV trend

# 1 row would be 1 calendar month 
# so 1 row = 1 calendar month 

#tables we will use would be 
#orders: purchase date and order identity
#order_items: units and revenue
#customers: unique cusotmer count


CREATE OR REPLACE VIEW vw_monthly_sales AS

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS sales_month,

#an order contains multiple items 
    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(oi.order_item_id) AS total_items,

    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,

    SUM(oi.price) AS total_revenue,

    SUM(oi.freight_value) AS total_freight,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value

FROM orders o

INNER JOIN order_items oi
    ON o.order_id = oi.order_id

INNER JOIN customer c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m');

#we are also calculating the AOV which is revenue / orders 

#lets test it

SELECT *
FROM vw_monthly_sales
ORDER BY sales_month
LIMIT 10;

-- 2016-09 has only 1 delivered order, which is plausible for the dataset's early period.
#2016-10 has 265 orders and 262 customers — meaning some customers placed multiple orders.
##total_items is greater than total_orders, as expected because an order can contain multiple items.
#average_order_value is correctly calculated as revenue ÷ distinct orders.
#The months are not continuous because we're grouping actual delivered orders, not generating artificial zero-sales months.


SELECT
    COUNT(*) AS total_months,

    SUM(total_orders) AS total_orders,
    SUM(total_items) AS total_items,
    SUM(unique_customers) AS sum_monthly_customers,

    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(total_freight), 2) AS total_freight

FROM vw_monthly_sales;

#so this file is completed which was analytics data layer 
#the  above views are reuable reporting views 

#96,478 orders → 110,197 items → $13.22M revenue