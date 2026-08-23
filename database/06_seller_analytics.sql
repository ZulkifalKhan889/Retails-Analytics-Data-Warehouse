use brazilian_ecommerce_analytics;

#first thing we do is  Seller sales performance 

#which seller generates most sales and revenue 

SELECT
    seller_id,
    
    #an order contains multiple products so order_id is repeated here in order_item dataset
    
    COUNT(DISTINCT order_id) AS orders_handled,
    COUNT(*) AS units_sold,

    ROUND(
        SUM(price),
        2
    ) AS revenue

FROM order_items

GROUP BY seller_id

ORDER BY revenue DESC
limit 10;

#limit is there so we can call it top 10 best perfromance seller

#also if we look at the 2nd seller he has generated almost same revenue as that of 1st one with less unit sld like 358 
#so we can say he has higer_value sales mix

#2nd query 
#avg seller price per seller
SELECT
    seller_id,

    COUNT(DISTINCT order_id) AS orders_handled,

    COUNT(*) AS units_sold,

    ROUND(SUM(price), 2) AS revenue,

    ROUND(
        SUM(price) / COUNT(*),
        2
    ) AS avg_selling_price

FROM order_items

GROUP BY seller_id

ORDER BY revenue DESC; 

#now as we discussed above the avg_selling price for 2nd seller is 543 thats why he generated more revenue with less items.
#it tells us about high value rather than high volume

#and the first seller is high volume seller

#query 3 
#seller customer satisfaction

#now we are finding the sellers generating the most revenue also providing a good exp to customer
WITH order_review AS (

    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM reviews
    GROUP BY order_id

)

SELECT
    oi.seller_id,

    COUNT(DISTINCT oi.order_id) AS orders_handled,

    COUNT(*) AS units_sold,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(AVG(orv.avg_review_score), 2) AS avg_review_score

FROM order_items oi

JOIN order_review orv
    ON oi.order_id = orv.order_id

GROUP BY oi.seller_id

ORDER BY revenue DESC;

#so from this we see clearly that those top sellers have also great reviews
#whilt the 3rd one is needed a bit of investigation regarding his product quality delivery exp, customer service etc 

#next query is seller revenue concentration 
#is the seller revenue spread across many seller or does a small group of sellers generate a large portion of revenue?

#to appraoch this we are gonna find the top 10 sellers and then we find what percentage of total revenue comes from those sellers

SELECT
    seller_id,
    ROUND(SUM(price), 2) AS revenue
FROM order_items
GROUP BY seller_id
ORDER BY revenue DESC
LIMIT 10;

#so if we look at the top1 and top 10 both got not much diff as one is at 229k other is t 135k still we find the pct below

SELECT
    ROUND(
        100.0 * SUM(revenue) /
        (SELECT SUM(price) FROM order_items),
        2
    ) AS top_10_revenue_share_pct
FROM (
    SELECT
        seller_id,
        SUM(price) AS revenue
    FROM order_items
    GROUP BY seller_id
    ORDER BY revenue DESC
    LIMIT 10
) AS top_sellers;

#look at the output it is 13.15 means the top 10 produced 13.15 pct of revenue among all seller it means the business is not dependent on those 10
#we have fairly diversified seller base so top 10 does not dominate the business

#next query is to find out the seller performance regarding product selling 

SELECT
    oi.seller_id,
    p.product_category_name,

    COUNT(*) AS units_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS revenue

FROM order_items oi

JOIN product p
    ON oi.product_id = p.product_id

#we are grouping it by both seller and category to find out how much each seller make from each category

GROUP BY
    oi.seller_id,
    p.product_category_name
ORDER BY
    revenue DESC;
    
#so look at the ouput several top sellers generate a substantial portion of thier revenue from specific categories partiuclay watches and gifts 

#so now next is what percentage of a seller revenue comes from thier main category?
#for example seller has total revenue 200k and 180k comes from selling watches and presents so w esay this seller is highly specialiazed in 
#watches and gifts because he generated 90% of revenue from it

WITH seller_category AS (

    SELECT
        oi.seller_id,
        p.product_category_name,
        SUM(oi.price) AS category_revenue

    FROM order_items oi

    JOIN product p
        ON oi.product_id = p.product_id

    GROUP BY
        oi.seller_id,
        p.product_category_name
),

seller_total AS (

    SELECT
        seller_id,
        SUM(category_revenue) AS total_revenue

    FROM seller_category

    GROUP BY seller_id
)

SELECT
    sc.seller_id,
    sc.product_category_name,
    ROUND(sc.category_revenue, 2) AS category_revenue,
    ROUND(st.total_revenue, 2) AS total_revenue,

    ROUND(
        100.0 * sc.category_revenue / st.total_revenue,
        2
    ) AS category_revenue_share

FROM seller_category sc

JOIN seller_total st
    ON sc.seller_id = st.seller_id

ORDER BY
    category_revenue_share DESC;
    
#now if we look at the result majority of them are 100% like 100% of seller revenue comes from that specific cateogry which means 
#in this dataset sellers are selling only that cateogry but we also have lesser pct for some sellers at the end which means they are not speciiclaized in that
#specific cateogry