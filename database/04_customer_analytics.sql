use brazilian_ecommerce_analytics;

#now in this section we are gonna find who are our customers, how they do behave, and which of them are valuables

#first we do is display customer profile to see what is happening like thier total spending max and min etc 

#so we are going to use 3 tables basically in order table we have 1 row = 1 order in order_item 1 row = 1 prod/item in order 

#now taking each customer we wont take customer_id but we will go for custmoer_unique_id because it represents each customer if it has made
#3 orders then this is appeare 3 times it is not unique bu represent each customer uniquely so we take this  thatss why we also be grouping by using this 

SELECT
    c.customer_unique_id,

    COUNT(DISTINCT o.order_id) AS order_count,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_spent,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS avg_order_value,

    MIN(o.order_purchase_timestamp) AS first_purchase_date,

    MAX(o.order_purchase_timestamp) AS last_purchase_date

FROM customer c

JOIN orders o
    ON c.customer_id = o.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

GROUP BY
    c.customer_unique_id
    
#lers order it descending order so we see this customers with multiple orders first
order by order_count desc;

## 2 as we found these repeat customers now we go for repear_purhase_behaviour as in kpi file we already know 3.12% are repeat customers but that is enot enough
#so we are going for customer order_frequency_distribution like how many customers made exactly 1, 2,3 ,4 5 orders?

#so what we do we take customer level data group it by order_count and then count the customers

SELECT
    order_count,
    COUNT(*) AS customer_count

FROM (
    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id) AS order_count

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id

) AS customer_profile

GROUP BY order_count

ORDER BY order_count;

#now if we look at the inner query then it is the same we have disussed above and the outr query is just counting customer and group it by order_count

#so we get how many customer made how many orders.
#look at the result it dramatically falls as purchase frequency increases the market has a strong on etime purchase pattern 


#NExt kpi so we have found how many order does each customer make?
#now next we are going for how reently did each customer purchase
#finding this is imp as customer who purchased yester day is diff from customer who purhcase months ago

#this theory is called RECENCY whihc is imp in RFM analysis 

#so we take the latest data and compare it against the customer date ut here we cant take todays date as this is historical data so what are we going to do 
#is take the latest date in this data and then find the recency of customers against it

#lets run this 

select max(order_purchase_timestamp) as latest_date
from orders;


#so lets built this on customer profile so this would be an outer query 
#the date is put outside the inner query as a filter which will be calculated for each customers

SELECT

#the follwing columsn already calculated in the inner query so outside we just select it.
    customer_unique_id,
    order_count,
    total_spent,
    avg_order_value,
    first_purchase_date,
    last_purchase_date,

    DATEDIFF(
        '2018-10-17',
        DATE(last_purchase_date)
    ) AS recency_days

FROM (
    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id) AS order_count,

        ROUND(
            SUM(oi.price),
            2
        ) AS total_spent,

        ROUND(
            SUM(oi.price) / COUNT(DISTINCT o.order_id),
            2
        ) AS avg_order_value,

        MIN(o.order_purchase_timestamp) AS first_purchase_date,

        MAX(o.order_purchase_timestamp) AS last_purchase_date

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id

) AS customer_profile

ORDER BY recency_days asc;

#so less recent customer is 773 days diff while more recent have 44 days diff

#so as numbers this does not make any sense so lets summarize this into useuful ranges 
#so the inner query is the same just take the outer query and use make it like a filter so 

SELECT
    CASE
        WHEN recency_days <= 90 THEN '0-90 days'
        WHEN recency_days <= 180 THEN '91-180 days'
        WHEN recency_days <= 365 THEN '181-365 days'
        WHEN recency_days <= 730 THEN '366-730 days'
        ELSE '731+ days'
    END AS recency_segment,

    COUNT(*) AS customer_count,


	#now this following is window function which will put percentage of customer in each ranges 
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct


#here starts the inner query whihch we haev understand i before
FROM (
    SELECT
        c.customer_unique_id,

        DATEDIFF(
            '2018-10-17',
            DATE(MAX(o.order_purchase_timestamp))
        ) AS recency_days

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
) AS customer_recency

GROUP BY recency_segment

ORDER BY
    CASE recency_segment
        WHEN '0-90 days' THEN 1
        WHEN '91-180 days' THEN 2
        WHEN '181-365 days' THEN 3
        WHEN '366-730 days' THEN 4
        WHEN '731+ days' THEN 5
    END;
    
#so we can say 70% of customers have  a last purchase older than 180 days

#now next is we combine the analysis of the above 2 to make our final analysis the frequency and the receny and we make whether:
#are our recent customers actually repeat buyers, or a most recent stil one-time buyers
#as we have drawn from the above 2:

#Frequency: most customers buy only once
#recency: most customers havent purchased recently

#so for each customer we find 
		#order count
        # and recency_days

#now this query is easy we take the above query as inner query  and outer query will be just labelling the ranges

#we are taking 180 as threshold 

SELECT
    CASE
        WHEN recency_days <= 180 AND order_count > 1
            THEN 'Recent + Repeat'

        WHEN recency_days <= 180 AND order_count = 1
            THEN 'Recent + One-time'

        WHEN recency_days > 180 AND order_count > 1
            THEN 'Old + Repeat'

        ELSE 'Old + One-time'
    END AS customer_segment,

    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct

FROM (
    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id) AS order_count,

        DATEDIFF(
            '2018-10-17',
            DATE(MAX(o.order_purchase_timestamp))
        ) AS recency_days

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id

) AS customer_profile

GROUP BY customer_segment

ORDER BY customer_count DESC;


#so we have 68% customer who have made thier order only once and that too 180 days ago

#now lets find out how much money does each customer actually generate

#which we call it customer monetory value
#so R: how recently did they purchase
#F: how many orders they make
#M: how much did they spend



SELECT
    customer_unique_id,

    COUNT(DISTINCT o.order_id) AS order_count,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_spent

FROM customer c

JOIN orders o
    ON c.customer_id = o.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

GROUP BY
    customer_unique_id

ORDER BY
    total_spent DESC;
    
#we are grouping by customer_unique_id as that represent the id of a uniue cusotmer every time he makes an orde and it is not unqie the more a 
#customer makes order the more it appers in dataset

#o now if we look at the top cusotmer he spent 13440 in one order so high spending does not mean high frequency 


#now what we did we found recency frequency and monetory now we combine them to find which customer are our most valuable customers when we consider 
#their recency purchase frequency and spending together

#so what we do below we find customer their recent days , order_count and total_spent 
#and then we will assign rfm score 


#here we are going into a new concept which is ntile() its a window function whic dividees the rows into specified number of roughly equal sized groups 

#but recency is reversed here low recency is better so we are going to use it in desc order

##now there is issue if we use the same like the ntile function on frequency then frequency is highly skewed like 92507 custmers have made exactly 1 order 
##so ntile() just cuts the sorted rows into five equally sized groups so some customers with frequency = 1
#could recieve F=1, F=2, F=3, F= 4, F= 5 so this is this issue so we are not ging for ntile() for this specific frequency whiel we will use it for 
#recency and monetory


WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,

        DATEDIFF(
            '2018-10-17',
            DATE(MAX(o.order_purchase_timestamp))
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        ROUND(
            SUM(oi.price),
            2
        ) AS monetary

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,

    -- Recency: lower days = better
    NTILE(5) OVER (
        ORDER BY recency_days DESC
    ) AS r_score,

    -- Frequency: business-defined scoring
    CASE
        WHEN frequency = 1 THEN 1
        WHEN frequency = 2 THEN 2
        WHEN frequency = 3 THEN 3
        WHEN frequency BETWEEN 4 AND 5 THEN 4
        ELSE 5
    END AS f_score,

    -- Monetary: higher spending = better
    NTILE(5) OVER (
        ORDER BY monetary ASC
    ) AS m_score

FROM customer_rfm;

#now if we look at the  customer 3 so 53 days since last purchased so score is 5 very decent score
#1 order so F is 1 decent. 2.20 is total spent so M is 1 very low spending so decent score now
#we can say this customer has RFM = 511

#now next is segemntation where we calculate the final score so we can call it RFm segemntation

#champiion
#now let say a customer has score like 555 so he has high R high F and High M so the business action can be to retian,reward, loyalty progrms, 
#exclusive offers

#loyal cusotmers 
#high r + high F  so they purhcase frequently and recently so protect the relationship could be business plan 
#etc


WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,

        DATEDIFF(
            '2018-10-17',
            DATE(MAX(o.order_purchase_timestamp))
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        ROUND(
            SUM(oi.price),
            2
        ) AS monetary

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
),

rfm_scores AS (

    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,

    CASE
        WHEN r_score >= 4
             AND f_score >= 4
             AND m_score >= 4
            THEN 'Champions'

        WHEN r_score >= 4
             AND f_score >= 4
            THEN 'Loyal Customers'

        WHEN r_score >= 4
             AND m_score >= 4
            THEN 'Big Spenders'

        WHEN r_score >= 4
             AND f_score <= 2
            THEN 'Recent Customers'

        WHEN r_score <= 2
             AND (f_score >= 3 OR m_score >= 3)
            THEN 'At Risk'

        ELSE 'Lost / Low Value'
    END AS customer_segment

FROM rfm_scores;


#so the query is just lengthy because we want it to be understanble and prettty clean so thats why it lengthy but there is no new concept that we did not discuss
#above 

#now next is we take these customers and aggregate it into some meaningful insights



WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,

        DATEDIFF(
            '2018-10-17',
            DATE(MAX(o.order_purchase_timestamp))
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        ROUND(SUM(oi.price), 2) AS monetary

    FROM customer c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
),

rfm_scores AS (

    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
),

segmented_customers AS (

    SELECT
        *,
        CASE
            WHEN r_score >= 4
                 AND f_score >= 4
                 AND m_score >= 4
                THEN 'Champions'

            WHEN r_score >= 4
                 AND f_score >= 4
                THEN 'Loyal Customers'

            WHEN r_score >= 4
                 AND m_score >= 4
                THEN 'Big Spenders'

            WHEN r_score >= 4
                 AND f_score <= 2
                THEN 'Recent Customers'

            WHEN r_score <= 2
                 AND (f_score >= 3 OR m_score >= 3)
                THEN 'At Risk'

            ELSE 'Lost / Low Value'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct

FROM segmented_customers

GROUP BY customer_segment

ORDER BY customer_count DESC;

#this query is not diffcult its just the above query but we put the outer query to find the aggregate and give it the group name based on the rfm profiles

#at risk are valuable customers but havnt purchased recently 

#so this file is done here. below is what we have done above:

#customer_order_behaviour
#order frequency distribution
#custmer recency
#cusotmer lifeccle behaviour 
#rfm analysis 
#rfm segmentation
