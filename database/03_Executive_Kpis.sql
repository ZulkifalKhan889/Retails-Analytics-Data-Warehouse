#Executive KPIs

use brazilian_ecommerce_analytics;

##KPI 1 
#we are checking how this business is performing overall for all the orders that are delivered


select count(distinct o.order_id) as total_orders, count(distinct o.customer_id)as total_customers,
count(oi.order_id) as total_items_sold, round(sum(oi.price+oi.freight_value),2) as total_revenue,
round(

sum(oi.price+oi.freight_value)/count(distinct o.order_id), 2) as average_order_value

#aov basically is how much revenue does an avg order generate 
from orders o
join order_items oi

on o.order_id = oi.order_id 
where o.order_status = 'delivered';


#next lets find out another kpi which is monthyl revenue and m-o-m growth 
#to answer quesitons like is the business growing or decling over months 

#now here we eb usign an imp window function lag() why? because we are looking into previous rows when finding growth over months so
#we will be also using cte which is another concept of separting query logically a temporary table whih we can work with it


with monthly_sales as (
select date_format(o.order_purchase_timestamp,'%Y-%m')  as sales_month,
count(distinct o.order_id) as total_orders,
sum(oi.price+oi.freight_value) as revenue 

from orders o 
join order_items oi
on o.order_id = oi.order_id

where order_status = 'delivered'
group by date_format(o.order_purchase_timestamp, "%Y-%m")

),

monthly_with_previous as (
select sales_month, total_orders, revenue, lag(revenue) over (order by sales_month) as previous_month_revenue
from monthly_sales

)

select sales_month, total_orders, round(revenue, 2) as revenue,

round(revenue/total_orders, 2) as average_order_value,

round(
((revenue- previous_month_revenue) / previous_month_revenue) * 100, 2) as mom_growth_pct
from monthly_with_previous order by sales_month;

#now if we look at the outptu there are some strange numbers like the 3rd row is in negative the 4 row is like 649657%
#now that is some serious number which is correct technically as we received one order from the previous month then in next month we received 750
#so the percentage is correct but that is big number which does not make sense when you have not read the previous month numbers 
#also another mistake is there is this 1 month missing maybe there was no order recorded (2016-11)
#lets investigate it below
#

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    SUM(order_status = 'delivered') AS delivered_orders
FROM orders
WHERE order_purchase_timestamp >= '2016-09-01'
  AND order_purchase_timestamp < '2017-03-01'
GROUP BY month
ORDER BY month;

#so basically that number has 0 orders so we are gonna update the above query so it displays even the month which are with 0 orders.
#now we are gonna write a recursive query to find that missing month and its orders 
#recursive cte can be used for many thing in dattabase
#it references itself repeatedly to geenrate or process rows until a stopping condition is reached

#used for:  data/calendar generation, organizational hierarchy, parent_child relaitonship etc 


WITH RECURSIVE months AS (

    SELECT
        DATE_FORMAT(
        
	#start from the earliest date in our dataset
            MIN(order_purchase_timestamp),
            '%Y-%m-01'
        ) AS month_start
    FROM orders

    UNION ALL

    SELECT
    #move forward one month at a time
        DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM months
    WHERE month_start < (
        SELECT DATE_FORMAT(
            MAX(order_purchase_timestamp),
            '%Y-%m-01'
        )
        FROM orders
    )
)

select DATE_FORMAT(month_start, '%Y-%m') AS sales_month
FROM months
ORDER BY month_start;

#now above we geenrated this calendar and nov month is here whihc was missing so what we do we left join with other data to get that missing month with zero orders
#so we will display that missing months 


#now combine the above queries to get thtm missing month and its numbers 

WITH RECURSIVE months AS (

    -- 1. Generate the complete month series
    SELECT
        DATE_FORMAT(
            MIN(order_purchase_timestamp),
            '%Y-%m-01'
        ) AS month_start
    FROM orders

    UNION ALL

    SELECT
        DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM months
    WHERE month_start < (
        SELECT
            DATE_FORMAT(
                MAX(order_purchase_timestamp),
                '%Y-%m-01'
            )
        FROM orders
    )
),

monthly_sales AS (

    -- 2. Calculate actual monthly sales
    SELECT
        DATE_FORMAT(
            o.order_purchase_timestamp,
            '%Y-%m-01'
        ) AS month_start,

        COUNT(DISTINCT o.order_id) AS total_orders,

        SUM(
            oi.price + oi.freight_value
        ) AS revenue

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        DATE_FORMAT(
            o.order_purchase_timestamp,
            '%Y-%m-01'
        )
)

-- 3. Keep every calendar month
SELECT
    DATE_FORMAT(
        m.month_start,
        '%Y-%m'
    ) AS sales_month,
#now as the orders and revenue is missing in nov month which would lead us to null so we put 0 instead of null using colaese

    COALESCE(s.total_orders, 0) AS total_orders,

    ROUND(
        COALESCE(s.revenue, 0),
        2
    ) AS revenue

FROM months m

LEFT JOIN monthly_sales s
    ON m.month_start = s.month_start

ORDER BY m.month_start;

#in here the 2018 9 and 10 month has also 0 orders delivered so that swhy they are 0 so it does not means the company revenue went from millions to 0 it means it 
#deleivered order are 0 while there are ordrs that were cancelled

### full kpi 2

-- KPI 2: Monthly Revenue and Month-over-Month Growth

WITH RECURSIVE months AS (

    -- Generate every month in the dataset
    SELECT
        DATE_FORMAT(
            MIN(order_purchase_timestamp),
            '%Y-%m-01'
        ) AS month_start
    FROM orders

    UNION ALL

    SELECT
        DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM months
    WHERE month_start < (
        SELECT
            DATE_FORMAT(
                MAX(order_purchase_timestamp),
                '%Y-%m-01'
            )
        FROM orders
    )
),

monthly_sales AS (

    -- Calculate actual monthly sales
    SELECT
        DATE_FORMAT(
            o.order_purchase_timestamp,
            '%Y-%m-01'
        ) AS month_start,

        COUNT(DISTINCT o.order_id) AS total_orders,

        SUM(
            oi.price + oi.freight_value
        ) AS revenue

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        DATE_FORMAT(
            o.order_purchase_timestamp,
            '%Y-%m-01'
        )
),

complete_monthly_sales AS (

    -- Combine calendar months with actual sales
    SELECT
        m.month_start,

        COALESCE(s.total_orders, 0) AS total_orders,

        COALESCE(s.revenue, 0) AS revenue

    FROM months m

    LEFT JOIN monthly_sales s
        ON m.month_start = s.month_start
),

monthly_with_previous AS (

    -- Get previous month's revenue
    SELECT
        month_start,
        total_orders,
        revenue,

        LAG(revenue) OVER (
            ORDER BY month_start
        ) AS previous_month_revenue

    FROM complete_monthly_sales
)

SELECT
    DATE_FORMAT(
        month_start,
        '%Y-%m'
    ) AS sales_month,

    total_orders,

    ROUND(
        revenue,
        2
    ) AS revenue,

    ROUND(
        revenue / NULLIF(total_orders, 0),
        2
    ) AS average_order_value,

    ROUND(
        (
            (revenue - previous_month_revenue)
            / NULLIF(previous_month_revenue, 0)
        ) * 100,
        2
    ) AS mom_growth_pct

FROM monthly_with_previous

ORDER BY month_start;


#now you would think why the percentage growth of previous month is zero in some columns like we understand the first one as there is no previous row or month 
#but what about the month 12 like the 4th row so basically the previous month of 12 is 11 which there was no ordered so we cant divide it by 0 as it leads to 
#undefined thats what the mom_growth_pct formula does so we keep the null in spite of undefined 

#	"Growth rate is undefined because the previous month's revenue was zero."

#KPI #3
#next is customer retention and Repeat purchase behaviour

#now why we picked the unique_id is becuase it belongs to the same customer everytime he orders while customer_id is assigned uniquely to each and every customer
#no matter even if someone does the orer again he gonna get the new customer id while his unqiue_cusotmer_id would be same

#so we are gonna use this unique_customer_id for analysis like repeat purchase, retention, cohort, RFM, and customer behaviour analysis 

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
ORDER BY order_count DESC
LIMIT 20;

#now in kpi 3 we are gona find out what percentage of our customer comes back and purchase again 
#the formula we are gonnna use inside the query is 

#repeat_customer/total_unique_customers x 100

#but before that we are gonna find out how many orders did each customer make? like how many customer make 1 order? how many make 2 orders etc 
#so we are gonna take the above query as a nested and then run on it an outer query 

SELECT
    order_count,
    COUNT(*) AS customer_count
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN customer c
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
) AS customer_orders
GROUP BY order_count
ORDER BY order_count
limit 5;
#Now if we look at the result 93099 customers have made 1 orders then 8 customer have made 5 orders means 5 orders are plaed by 8 customers

#now below is the total kpi here we are also using the formula that wwe commented it above

SELECT
    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN order_count >= 2 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN order_count >= 2 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS repeat_customer_rate_pct

FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count

    FROM orders o

    JOIN customer c
        ON o.customer_id = c.customer_id

    GROUP BY c.customer_unique_id

) AS customer_orders;


#interpretation: only about 3.12% of customers made 2+ purchases during the dataset period.
#now what we get from this is 96.88% purchased only once so this market has a huge one-time customer base meaning about 96.88% purchased only once

##KPI 4 order cancellation rate 

#we are gonna find out what percentage of all placed ordes were cancelled

#the formula is cancellation_rate = cancelled_orders/total_orders x 100

SELECT
    COUNT(DISTINCT order_id) AS total_orders,

    SUM(
        CASE
            WHEN order_status = 'canceled' THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN order_status = 'canceled' THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT order_id),
        2
    ) AS cancellation_rate_pct

FROM orders;

#if we look at the result then order cacnellation is not that big issue we haev like 0.63 orders cacnellation out of 100 so order cancellation is not that issue
#but the abive insight about why arent more cusomter coming backs as repeat customer rate was very low so that is more concering.


#no we have kpi 5 which we will be finding this deleivery performance like: 

#how long does an order actually take to reach the customer?
#how often does an order delivered later than the estimated deliverry date?

SELECT
    COUNT(DISTINCT order_id) AS delivered_orders,

    ROUND(
        AVG(
        
        #finding the avg diff in days between order delivere dand order purchased so we find how many days it took between purchasing and getting into hands of customer
            TIMESTAMPDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ),
        0
    ) AS avg_delivery_days

FROM orders

WHERE order_status = 'delivered'

#now the below condition is to protect from calculating the a delievery time where the actual delievery timestamp is missing 
  AND order_delivered_customer_date IS NOT NULL;

#so with this insight we can say the avg order took 12 days to reach the customer.

#now we find late_delievery_date 
#we are gonna find out what percentage of delivered orders arrived after the estimated delievery date 

#formula is if actual delievery date > estimated then its late

SELECT
    COUNT(DISTINCT order_id) AS delivered_orders,

    SUM(
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN order_delivered_customer_date > order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT order_id),
        2
    ) AS late_delivery_rate_pct

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
  
  #so based onthe result 8 out of 100 orders arrived after the estimated data means they are deleivered late
	
    
#now combine both the abve insihts that we get in kpi 5 
SELECT
    COUNT(DISTINCT order_id) AS delivered_orders,

    ROUND(
        AVG(
            TIMESTAMPDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ),
        2
    ) AS avg_delivery_days,

    SUM(
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN order_delivered_customer_date > order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT order_id),
        2
    ) AS late_delivery_rate_pct

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
  
  #
    
    
### KPI 6 customer satisfaction
#now as we know we have review _score column so what are we gonna do is we find insight from it not just avg review but also negaitve review
#negative reviw would be we take 1 and 2 review sscore divide it by total reviews and multiply by 100 for psotive we take 5 and 4 score and for neutral we 
#take 3

SELECT
    COUNT(*) AS total_reviews,

    ROUND(
        AVG(review_score),
        2
    ) AS avg_review_score,

    SUM(
        CASE
            WHEN review_score IN (4, 5)
            THEN 1
            ELSE 0
        END
    ) AS positive_reviews,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN review_score IN (4, 5)
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS positive_review_rate_pct,

    SUM(
        CASE
            WHEN review_score IN (1, 2)
            THEN 1
            ELSE 0
        END
    ) AS negative_reviews,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN review_score IN (1, 2)
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS negative_review_rate_pct

FROM reviews;

#the concepts used in this query are easy select round and case and conditon basic concepts just combined in one query

### kpi 7
#so this would be about payment
#now one thing here is one order_id can have mutiple payments rows because an order can involve mutiple payments so we are gonan take the order_id 
#unique

SELECT
    payment_type,

    COUNT(DISTINCT order_id) AS orders,

    ROUND(
        SUM(payment_value),
        2
    ) AS total_payment_value,

    ROUND(
        AVG(payment_value),
        2
    ) AS avg_payment_value

FROM payments

GROUP BY payment_type

ORDER BY total_payment_value DESC;

#form the above we can say credit card domintes the payment methods so we can say our market is heavily dependent on credit_card pament 
#so its availaibily and reliability is important

#if there is an major friciton in credit card it could affect a large portion of transacitons 


### last kpi 8

#so we are gonna find out how much revenue does the business generte per order n avg?
#we also find AOV = total_order_revenue/no of orders

SELECT
    COUNT(DISTINCT order_id) AS total_orders,

    ROUND(
        SUM(price),
        2
    ) AS total_product_sales,

    ROUND(
        SUM(price) / COUNT(DISTINCT order_id),
        2
    ) AS average_order_value

FROM order_items;

#now why we selec unique order id because in order_items table each order is not unique becuase each order have inside all the products 
#so if order is 190 then it is appeared 3 times if total prod bought in that order is 3 so thats why we go for unique

	
#now to the average_order_value is 137 so we can say the avg order generated approximately 137.75 in product  sales value









