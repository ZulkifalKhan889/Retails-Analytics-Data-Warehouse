use brazilian_ecommerce_analytics;

#first query is to find which payment methods do customer use most frequently

select * from payments;
select payment_type, count(*) as payment_count
from payments 
group by payment_type
order by payment_count desc;

#credit card is the dominant paying method 

#now lets find out which payment method handles the most money?

SELECT
    payment_type,
    COUNT(*) AS payment_count,

    ROUND(
        SUM(payment_value),
        2
    ) AS total_payment_value

FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

#so credit card is the most used and it also handled most of the money 

#next we find out which payment methods are typically used for higher_value_payments so we basiclaly find the average payment value

SELECT
    payment_type,

    COUNT(*) AS payment_count,

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

ORDER BY avg_payment_value DESC;

#so it is still credit card so avg payment value for credit card is 163

#now there is another column in this datasert whihc is payment_installement basically payment_installements splits the the total cost of the
#product into smaller refular chunks to be paid over time instead of all at once 

#as ppl use this when they are buying a high value product in general but lets see if this is the same in our data 

SELECT
    payment_installments,

    COUNT(*) AS payment_count,

    ROUND(
        SUM(payment_value),
        2
    ) AS total_payment_value,

    ROUND(
        AVG(payment_value),
        2
    ) AS avg_payment_value

FROM payments

#now here we filtered it the reasn is 	installements are mainly revelants to credit_card_payment

WHERE payment_type = 'credit_card'

#grouped it by this because we need to put 1-installement together, 2-installement payment together, 3 together like grouping it by 
GROUP BY payment_installments
ORDER BY payment_installments;


#look at the pattern the the higher is the avgpayment_value the higher are the installements so expensive products were bough in installements


#now we need to cinfirm do cusotmer needs more installemetns when the paymentr amount is higher

#we will create the payment groups to put that into using cases concept in sql

SELECT
    CASE
        WHEN payment_installments = 1 THEN '1 installment'
        WHEN payment_installments BETWEEN 2 AND 3 THEN '2-3 installments'
        WHEN payment_installments BETWEEN 4 AND 6 THEN '4-6 installments'
        WHEN payment_installments BETWEEN 7 AND 9 THEN '7-9 installments'
        WHEN payment_installments >= 10 THEN '10+ installments'
    END AS installment_group,

    COUNT(*) AS payment_count,

    ROUND(AVG(payment_value), 2) AS avg_payment_value

FROM payments

WHERE payment_type = 'credit_card'
  AND payment_installments > 0

GROUP BY
    installment_group

ORDER BY
    avg_payment_value;

#now look into the avg payment_value in each installement the higher it is the higher the installement group
#so we can draw the insight that majority of installement are used for higher prices product 


#now next is what percentage of orders are paid using multiple installements and how imp are installement purchases to total payment value

#so 1 installement would be consider as single payment purchase 2+ are installement purchase

#so out of all credit_card payment how many are actually being split into multipl einstlalment
WITH installment_summary AS (

    SELECT
        CASE
            WHEN payment_installments = 1
                THEN '1 installment'
            WHEN payment_installments >= 2
                THEN '2+ installments'
        END AS installment_type,

        COUNT(*) AS payment_count,

        SUM(payment_value) AS total_payment_value

    FROM payments

    WHERE payment_type = 'credit_card'
      AND payment_installments > 0

    GROUP BY
        installment_type
)

SELECT
    installment_type,

    payment_count,

    ROUND(total_payment_value, 2) AS total_payment_value,

    ROUND(
        100.0 * payment_count /
        SUM(payment_count) OVER (),
        2
    ) AS payment_share_pct,

    ROUND(
        100.0 * total_payment_value /
        SUM(total_payment_value) OVER (),
        2
    ) AS value_share_pct

FROM installment_summary
ORDER BY payment_count DESC;

#now look at the result we have strong installement plans in the business they are 80% credit card payment value so installmenet are dominant	