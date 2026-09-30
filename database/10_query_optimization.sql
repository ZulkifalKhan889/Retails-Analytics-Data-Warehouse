use brazilian_ecommerce_analytics;

#first topic is EXPLAIN

#lets take a query and lets use EXPLAIN there

EXPLAIN
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
ORDER BY total_revenue DESC;

#now if we look at the type then it is ALL which means it is doing a full table scan.
#

#lets create an index
#now and index is like a book without an index see through every page to find "delivered".

#with an index: 
#look at the index find where "delivered" occurs go directly there 

#lets make an index 

create index idx_orders_status
on orders(order_status);

EXPLAIN
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
ORDER BY total_revenue DESC;

#if we look at the before one then it started with orders then customers and then order_items  and orders had type = all
#but after adding this index it starrted with customers then orders then order_items 
#
#the question now is why we create an index on order_status:
#becuase our filter in where is on order_status so we can use the index there to find the required result 

#so basically the indexes give mysql more options the optimizer chooses which options it thinks is the cheapest 

#now lets do the composite index 
#we are going to do two things first find orders for this customer + keep only delivered orders 
#now composite index puts  both columns into one index 


create index idx_orders_customers_status
on orders(customer_id, order_status);

#we are using customer_id first and then order_status second becuase our query joins through customer_id and then filters by order_status.


EXPLAIN
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
ORDER BY total_revenue DESC;

#now after adding new index it changed the plan and started with order_items -> orders -> order_items
#now the first step is a full scan of order_items 
#now our compiste index exists but mysql repused to use it also it knows this exists 

#now we are using explain analyze to know fully wahts going on 

EXPLAIN ANALYZE
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
ORDER BY total_revenue DESC;

#now 


#next is limit becuase in real world we dont always need to get all the rows so limit is also  a way to optimize

#

EXPLAIN ANALYZE
SELECT
    c.customer_unique_id,
    ROUND(SUM(oi.price), 2) AS total_revenue

FROM orders o

INNER JOIN customer c
    ON o.customer_id = c.customer_id

INNER JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_unique_id

ORDER BY total_revenue DESC

LIMIT 10;


#now check what indexes we have currently

SHOW INDEX FROM orders;

