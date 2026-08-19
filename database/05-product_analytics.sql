use brazilian_ecommerce_analytics;

#now next is to find out what are our customer buying also which product or category are driving sales, revenue etc 

#1 most purchased product 

select product_id , count(*) as units_sold from order_items 
group by product_id order by units_sold desc;

#but we dont knwo the product cateogry from the id so we are going to display the names
SELECT
    oi.product_id,
    p.product_category_name,
    COUNT(*) AS units_sold
FROM order_items oi
JOIN product p
    ON oi.product_id = p.product_id
GROUP BY
    oi.product_id,
    p.product_category_name
ORDER BY units_sold DESC;

#now we can say the product in moveis_decoracao was the highest volume product 

##next is revenue by product

SELECT
    product_id,
    ROUND(SUM(price), 2) AS revenue
FROM order_items
GROUP BY product_id
ORDER BY revenue DESC
limit 10;


#insight
#so if we look at the previous then this query we get that the product selling the most units is not necessary the product generating the most revenue 


#now we do another which we will find out unit vs revenue vs avg_selling_price 
#we wnat to find out are the products geenrating revenue becuase they sell a lot of units or becuase they are expensive or both 

#avg_selling_price  = total_revenue/units_sold
#so avg seeeling price is avg amoount paid per unit

SELECT 
    oi.product_id,
    COUNT(*) AS units_sold,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(SUM(oi.price) / COUNT(*), 2) AS avg_selling_price
FROM
    order_items oi
GROUP BY oi.product_id
ORDER BY revenue DESC;

#now look at the product 3 which sold 35 units but generted like 48k revenue because its avg seling price is 1397 so
#if the product has generated more revenue it does not mean that product has sold the most 

#now that was which individual product perform the best
#next is whihc product category drive the business

SELECT
    p.product_category_name,
    COUNT(*) AS units_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS revenue,

    ROUND(
        SUM(oi.price) / COUNT(*),
        2
    ) AS avg_selling_price

FROM order_items oi

JOIN product p
    ON oi.product_id = p.product_id
GROUP BY
    p.product_category_name
ORDER BY
    revenue DESC;
    
#now we see the cateogry name units_sold and selling price but not for product but for category 
#we can sat beaty and health is the stringest revenue cateogory among these 

#next is we are adding are the categories generating the most sale and revenue also reciving good customer reviews

SELECT
    p.product_category_name,

    COUNT(*) AS units_sold,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(
        AVG(r.review_score),
        2
    ) AS avg_review_score

FROM order_items oi

JOIN product p
    ON oi.product_id = p.product_id

JOIN reviews r
    ON oi.order_id = r.order_id

GROUP BY
    p.product_category_name

ORDER BY
    revenue DESC;
#remember the review is associated with the order not with the product

#so from the result beleza & saude is the strongest overall among these categories 
#highest revenue and string reviews

WITH order_review AS (

    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM reviews
    GROUP BY order_id
)

SELECT
    p.product_category_name,

    COUNT(*) AS units_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS revenue,

    ROUND(
        AVG(orv.avg_review_score),
        2
    ) AS avg_review_score

FROM order_items oi

JOIN product p
    ON oi.product_id = p.product_id

JOIN order_review orv
    ON oi.order_id = orv.order_id
GROUP BY
    p.product_category_name
ORDER BY
    revenue DESC; 
    
#now here above we have used the inner join so if 80 out of 100 orders have reviews then it takes only those orders 
#so for this specific we only care about the sales where we have customer feedback  

#now we can also use the left join but that would have inluded all the sales and and for the orders which  lack review we would be getting  null 
#so here our main focus is the sale of those categories that have reviews so we find whats the customer feedback for thise product that are sold the most.
#so we can say these are reviewd order the records of reviewed order 


#next is we analyze is the business heavily dependent on a small number of product or is revenue spread across many products?
SELECT
    product_id,

    COUNT(*) AS units_sold,

    ROUND(
        SUM(price),
        2
    ) AS revenue

FROM order_items

GROUP BY product_id

ORDER BY revenue DESC

LIMIT 10;

#so the above are the top 10 product we are gonna divide it on total_product_revenue  and then x 100 to find the dependeny

SELECT
    ROUND(SUM(price), 2) AS total_revenue
FROM order_items;

#so lets wite the whole query 

#this first here is the temporary table which finds the revenue per product 
WITH product_revenue AS (
    SELECT
        product_id,
        SUM(price) AS revenue
    FROM order_items
    GROUP BY product_id
),

#now we want the top 10 fro the above finding 

top_10 AS (
    SELECT
        SUM(revenue) AS top_10_revenue
    FROM (
        SELECT
            revenue
        FROM product_revenue
        ORDER BY revenue DESC
        LIMIT 10
    ) t
),
#the t above is the name of the subquery 
 
#now we need total reveneue so we apply that formula we discuused above to like the top 10 revnue / total_revneu x 100

total AS (
    SELECT
        SUM(revenue) AS total_revenue
    FROM product_revenue
)


SELECT
    ROUND(top_10.top_10_revenue, 2) AS top_10_revenue,
    ROUND(total.total_revenue, 2) AS total_revenue,
    ROUND(
        top_10.top_10_revenue * 100.0 / total.total_revenue,
        2
    ) AS top_10_revenue_share_pct
    
#now below is the cross join we use to keep the the above 3 columns in separete rows so we 
FROM top_10
CROSS JOIN total;

#now we can say that the business is not heavily dependent on top products but all products are contributing accordingly


#Next is best and underperforming product so they might get attention

#best performer could be high volume_high + high  revenue+string reviews 

#and underperformer could be low_volume+low_revenue_weak_reviews

SELECT
    oi.product_id,
    COUNT(*) AS units_sold,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
LEFT JOIN reviews r
    ON oi.order_id = r.order_id
GROUP BY oi.product_id
ORDER BY revenue DESC;

WITH product_performance AS (
    SELECT
        oi.product_id,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS revenue,
        AVG(r.review_score) AS avg_review_score
    FROM order_items oi
    LEFT JOIN reviews r
        ON oi.order_id = r.order_id
    GROUP BY oi.product_id
)

SELECT
    ROUND(AVG(units_sold), 2) AS avg_units_sold,
    ROUND(AVG(revenue), 2) AS avg_revenue,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score
FROM product_performance;

#now this gives us only one row which is baseline we are going to use this to categorize the prod into high prformer and low performer


#the below query will be huge we are putting the baseline above query in it

WITH product_performance AS (
    SELECT
        oi.product_id,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS revenue,
        AVG(r.review_score) AS avg_review_score
    FROM order_items oi
    LEFT JOIN reviews r
        ON oi.order_id = r.order_id
    GROUP BY oi.product_id
),

baseline AS (
    SELECT
        AVG(units_sold) AS avg_units_sold,
        AVG(revenue) AS avg_revenue,
        AVG(avg_review_score) AS avg_review_score
    FROM product_performance
)

SELECT
    p.product_id,
    p.units_sold,
    ROUND(p.revenue, 2) AS revenue,
    ROUND(p.avg_review_score, 2) AS avg_review_score,

    CASE
        WHEN p.units_sold > b.avg_units_sold
        THEN 'High Volume'
        ELSE 'Low Volume'
    END AS volume_category,

    CASE
        WHEN p.revenue > b.avg_revenue
        THEN 'High Revenue'
        ELSE 'Low Revenue'
    END AS revenue_category,

    CASE
        WHEN p.avg_review_score >= b.avg_review_score
        THEN 'Strong Reviews'
        ELSE 'Weak Reviews'
    END AS review_category

FROM product_performance p

#attach the baseline to every product 
CROSS JOIN baseline b

ORDER BY p.revenue DESC;

#if we look at the baseline result then we have like 3.44 avg units sold which is pretty lower so majority of the product would be place
#as high_volume but the data is like this we dont have that much repetition in it so but still we have the insights

#lets label these 

WITH product_performance AS (
    SELECT
        oi.product_id,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS revenue,
        AVG(r.review_score) AS avg_review_score
    FROM order_items oi
    LEFT JOIN reviews r
        ON oi.order_id = r.order_id
    GROUP BY oi.product_id
),

baseline AS (
    SELECT
        AVG(units_sold) AS avg_units_sold,
        AVG(revenue) AS avg_revenue,
        AVG(avg_review_score) AS avg_review_score
    FROM product_performance
),

classified_products AS (
    SELECT
        p.product_id,
        p.units_sold,
        p.revenue,
        p.avg_review_score,

        CASE
            WHEN p.units_sold > b.avg_units_sold
                 AND p.revenue > b.avg_revenue
                 AND p.avg_review_score >= b.avg_review_score
                THEN 'Best Performer'

            WHEN p.units_sold > b.avg_units_sold
                 AND p.revenue > b.avg_revenue
                 AND p.avg_review_score < b.avg_review_score
                THEN 'Revenue & Review Concern'

            WHEN p.units_sold > b.avg_units_sold
                 AND p.revenue <= b.avg_revenue
                THEN 'High Volume / Low Revenue'

            WHEN p.units_sold <= b.avg_units_sold
                 AND p.revenue > b.avg_revenue
                THEN 'Low Volume / High Revenue'

            WHEN p.units_sold <= b.avg_units_sold
                 AND p.revenue <= b.avg_revenue
                 AND p.avg_review_score < b.avg_review_score
                THEN 'Potential Underperformer'

            ELSE 'Average Performer'
        END AS performance_category

    FROM product_performance p
    CROSS JOIN baseline b
)

SELECT
    product_id,
    units_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(avg_review_score, 2) AS avg_review_score,
    performance_category
FROM classified_products
ORDER BY revenue DESC;