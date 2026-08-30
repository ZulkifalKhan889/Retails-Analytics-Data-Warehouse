use brazilian_ecommerce_analytics;

#now this phase is about delivery analytics so we will do like overall delievery time and delivery performance
#etc
show tables;

select * from orders;
#so the delveiry info is stored in order table 

#first lets find out overall delivery time
#like on avg how many days does it take for an order to reach the customer

SELECT
    COUNT(*) AS delivered_orders,

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

    MIN(
        TIMESTAMPDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS fastest_delivery_days,

    MAX(
        TIMESTAMPDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS slowest_delivery_days

FROM orders

WHERE order_delivered_customer_date IS NOT NULL;

#timestampdiff is used to define the diff between the time

#alo the result is avg is 12 days and the late most delivery is 209 whihc is kinda an outliers
#also the fastest is 0 means it reached on the same day it was ordered


##NExt is Delivery time distribution

#now we are gonna find out how are delivery time distributed 	grouping the delivery time into ranges

SELECT
    CASE
		
        WHEN delivery_days BETWEEN 0 AND 3 THEN '0-3 days'
        WHEN delivery_days BETWEEN 4 AND 7 THEN '4-7 days'
        WHEN delivery_days BETWEEN 8 AND 14 THEN '8-14 days'
        WHEN delivery_days BETWEEN 15 AND 30 THEN '15-30 days'
        WHEN delivery_days > 30 THEN '30+ days'
    END AS delivery_time_group,

    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct

FROM (
    SELECT
        TIMESTAMPDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        ) AS delivery_days
    FROM orders
    WHERE order_delivered_customer_date IS NOT NULL
   
) AS delivery_data

GROUP BY delivery_time_group

ORDER BY
    CASE delivery_time_group
        WHEN '0-3 days' THEN 1
        WHEN '4-7 days' THEN 2
        WHEN '8-14 days' THEN 3
        WHEN '15-30 days' THEN 4
        WHEN '30+ days' THEN 5
    END;

#now here are some null rows which show the delivery date is lower than 0 days lets investigate that

SELECT
    COUNT(*) AS null_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND TIMESTAMPDIFF(
        DAY,
        order_purchase_timestamp,
        order_delivered_customer_date
      ) IS NULL;
      
      
      #these 2965 rows which are returned as null becuase order_delivered customer date is not null
      #and order_purchase timestamp is likely null so thats why returend is also null

#interprettion

#About one-third of orders arrive within a week.
#The largest single group takes 8–14 days.
#More than one-quarter take longer than 15 days.

#analysis 3 ontime vs late_deliveries

SELECT
    CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date
            THEN 'On Time'
        WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 'Late'
    END AS delivery_status,

    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct

FROM orders

WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL

GROUP BY delivery_status

ORDER BY order_count DESC;

#so we can say out of 100 orders 92 arrived in time while 8 were late

#now we are finding out how much were they late in days 

SELECT
    COUNT(*) AS late_orders,

    ROUND(
        AVG(
            TIMESTAMPDIFF(
                DAY,
                order_estimated_delivery_date,
                order_delivered_customer_date
            )
        ),
        2
    ) AS avg_days_late,

    MIN(
        TIMESTAMPDIFF(
            DAY,
            order_estimated_delivery_date,
            order_delivered_customer_date
        )
    ) AS min_days_late,

    MAX(
        TIMESTAMPDIFF(
            DAY,
            order_estimated_delivery_date,
            order_delivered_customer_date
        )
    ) AS max_days_late

FROM orders

WHERE order_delivered_customer_date > order_estimated_delivery_date
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
  
  #so from result we can say late orders were delayed by on avg 9 days 
  #now the min is 0 because order was later but less than 24 hours of estimated days 
  
  
  #next is lets check out do late delivery get lower reviews
  
  SELECT
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On Time'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
    END AS delivery_status,

    COUNT(DISTINCT o.order_id) AS order_count,

    ROUND(AVG(r.review_score), 2) AS avg_review_score

FROM orders o

INNER JOIN reviews r
    ON o.order_id = r.order_id

WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND r.review_score IS NOT NULL

GROUP BY delivery_status

ORDER BY order_count DESC;

#so late reviews are often associated with low reviews 