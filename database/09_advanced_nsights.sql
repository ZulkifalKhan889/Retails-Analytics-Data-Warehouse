##Advanced analysis

use brazilian_ecommerce_analytics;

#1 customer cohort analysis
#cohort means the customer who started roughly at the same time
#here we are going to group the customers according to the month of thier first purchase

#now why we do this we want to find out do customers come back and purchase again after thier first purchase?

#eg january 100 cohort 	
#100 customers made thier first purchase then next month 20 customers purchased again so retention is 20%


#folowing is the query to find out the first purchase of each customer
SELECT
    customer_id,
    MIN(order_purchase_timestamp) AS first_purchase_date
FROM orders
WHERE order_status = 'delivered'
GROUP BY customer_id;

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM orders o

    INNER JOIN customer c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
),

customer_first_purchase AS (

    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_date
    FROM customer_orders
    GROUP BY customer_unique_id
),

customer_cohorts AS (

    SELECT
        customer_unique_id,
        DATE_FORMAT(
            first_purchase_date,
            '%Y-%m-01'
        ) AS cohort_month
    FROM customer_first_purchase
),

customer_activity AS (

    SELECT DISTINCT
        co.customer_unique_id,
        cc.cohort_month,
        DATE_FORMAT(
            co.order_purchase_timestamp,
            '%Y-%m-01'
        ) AS purchase_month
    FROM customer_orders co

    INNER JOIN customer_cohorts cc
        ON co.customer_unique_id = cc.customer_unique_id
),

cohort_activity AS (

    SELECT
        customer_unique_id,
        cohort_month,
        purchase_month,

        TIMESTAMPDIFF(
            MONTH,
            cohort_month,
            purchase_month
        ) AS months_since_first_purchase

    FROM customer_activity
),

cohort_sizes AS (

    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    ca.months_since_first_purchase,
    COUNT(DISTINCT ca.customer_unique_id) AS active_customers,
    cs.cohort_size,

    ROUND(
        100.0 *
        COUNT(DISTINCT ca.customer_unique_id)
        / cs.cohort_size,
        2
    ) AS retention_rate_pct

FROM cohort_activity ca

INNER JOIN cohort_sizes cs
    ON ca.cohort_month = cs.cohort_month

GROUP BY
    ca.cohort_month,
    ca.months_since_first_purchase,
    cs.cohort_size

ORDER BY
    ca.cohort_month,
    ca.months_since_first_purchase;
    
#Revenue concentration/ pareto analysis

#here we analyze how much of the business revenue comes from the highest value customer

#here we are dividing the customers into 10 groups then rank by total spendings bottom 10% spenders would be lowest and 
#top 10% spenders would be highest spenders 


WITH customer_revenue AS (

    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS total_revenue

    FROM orders o

    INNER JOIN customer c
        ON o.customer_id = c.customer_id

    INNER JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_unique_id
),

customer_deciles AS (

    SELECT
        customer_unique_id,
        total_revenue,

#here waht ntile does is sort customers by lowest spending to highest spending and then split them into 10 groups like 100 cusomters so this groups them 
#into 10 groups and then ordering by total_revenue so decile 1 is lowest revenue cusotmers and decile 10 is highes 

        NTILE(10) OVER (
            ORDER BY total_revenue
        ) AS revenue_decile

    FROM customer_revenue
)

SELECT
    revenue_decile,

    COUNT(*) AS customer_count,

    ROUND(
        SUM(total_revenue),
        2
    ) AS decile_revenue,

    ROUND(
        100.0 * SUM(total_revenue)
        / SUM(SUM(total_revenue)) OVER (),
        2
    ) AS revenue_share_pct

FROM customer_deciles

GROUP BY revenue_decile

ORDER BY revenue_decile;
#from the reuslt we can say the top 10% customer geenrate 41% revenue 
#so these customers deserve attention becuase losing them could have a much larger finanacial impact than losing an avg customer


#now we are ranking sellers within each category 

#within each product ccategory, which sellers are the top performer?
#so the seller be compared against other sellers but within thier own category not overall sellers

#so for this we are gonna use rank and partition now partition means not overall ranking but ranking within the category 

WITH seller_category_revenue AS (

    SELECT
        oi.seller_id,
        p.product_category_name AS category,

        SUM(oi.price) AS total_revenue

    FROM order_items oi

    INNER JOIN product p
        ON oi.product_id = p.product_id

    INNER JOIN orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL

    GROUP BY
        oi.seller_id,
        p.product_category_name
),

ranked_sellers AS (

    SELECT
        seller_id,
        category,
        total_revenue,

        RANK() OVER (
            PARTITION BY category
            ORDER BY total_revenue DESC
        ) AS seller_rank

    FROM seller_category_revenue
)

SELECT
    seller_id,
    category,
    ROUND(total_revenue, 2) AS total_revenue,
    seller_rank

FROM ranked_sellers

WHERE seller_rank <= 3

ORDER BY
    category,
    seller_rank;
    
#next 

#now we have this analysis which is running revenue and moving average so what we gonna do we take this
#month calculate its monthyl revnue, running revenue , and 3-month moving avg
#so revenue would be that month total revenue, running revenue would be how much we made from the begginning to that month revnue and 
# 3 -month moving avg would be avg revenue over the current month +previous 2 month

#we are gonna use window function for such query 

WITH monthly_revenue AS (

    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS month,
        SUM(oi.price) AS monthly_revenue

    FROM orders o

    INNER JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')
),

revenue_analysis AS (

    SELECT
        month,
        monthly_revenue,

        -- Running total of revenue
        SUM(monthly_revenue) OVER (
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_revenue,

		#the above line means keep adding each months revenue to everything that came before it 
        
        -- 3-month moving average
        AVG(monthly_revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3_months


	
    FROM monthly_revenue
)

SELECT
    month,

    ROUND(monthly_revenue, 2) AS monthly_revenue,

    ROUND(running_revenue, 2) AS running_revenue,

    ROUND(moving_avg_3_months, 2) AS moving_avg_3_months

FROM revenue_analysis

ORDER BY month;

#remeber the result for 3rd row like for month 12 is 10 that becuase the 11 month is mising there were no orders delievered so the avg gets wroing 
#its averaging the 3 months skipping 11 thats why avg si wrong 



#Customer value segmentation
#we have already done the rfm here we are not repeating it we are doing 
# how much revenue does each customer geenrate and how valuable are they relative to the rest of the customer base
#
#we will check how much revenue each customer generate, and how valuable are they relative to the rest of the customer base

#divideing the cusotmer into 4 revenue groups using window function ntile()

WITH customer_revenue AS (

    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS total_revenue

    FROM orders o

    INNER JOIN customer c
        ON o.customer_id = c.customer_id

    INNER JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_unique_id
),

customer_quartiles AS (

    SELECT
        customer_unique_id,
        total_revenue,

        NTILE(4) OVER (
            ORDER BY total_revenue
        ) AS revenue_quartile

    FROM customer_revenue
)

SELECT
    revenue_quartile,

    COUNT(*) AS customer_count,

    ROUND(
        SUM(total_revenue),
        2
    ) AS total_revenue,

    ROUND(
        AVG(total_revenue),
        2
    ) AS avg_customer_revenue,

    ROUND(
        100.0 * SUM(total_revenue)
        / SUM(SUM(total_revenue)) OVER (),
        2
    ) AS revenue_share_pct

FROM customer_quartiles

GROUP BY revenue_quartile

ORDER BY revenue_quartile;

#looking at the output the top 25% of customers generate 62% of total revenue 
#one quarter of the customer are responsible for greater revneu so we can say the customer base is highly skewed becuase avg customer 
#in highest quartile which is last one generates roughly 12X more revenue tht the lowest one which is top quaarter in output 