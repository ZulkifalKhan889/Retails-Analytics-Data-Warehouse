use brazilian_ecommerce_analytics;
#using database we created previous 

#each table is basically defiing the rules for storiing one business entity
#first is customer it is a master table without it we dont have orders as customers make orders 
#so customer has one to many relationship with the orders

#note that below we have char(32) because in dataset we have exactly 32 character in this primary key column 
#also we did not write null or uniquewith primary key becuase when we wrote the primary key then null and 
#unique applied automatically.

create table customer (
customer_id char(32) primary key,
customer_unique_id char(32) not null,
customer_zip_code_prefix int not null,
customer_city varchar(100) not null,
customer_state char(2) not null);
show tables;
describe customer;

#table 2
#this table is so imp it is like the heat of the database so we are gonna do it carefully
#because orders cant exist without cust, payment, shipment, review etc

create table orders (
order_id char(32) primary key,
customer_id char(32) not null,
order_status varchar(20) not null,
order_purchase_timestamp DATETIME NOT NULL,
order_approved_at datetime,
order_delievered_carrier_date datetime,
order_delivered_customer_date datetime,
order_estimated_delivery_date DATEtime, 

#the fk_orders_customer is just the name of this constraint 
#this constraint tells dont insert the order if customer doesnot exist

constraint fk_orders_customer
	foreign key(customer_id)
    references customer(customer_id)
);
show tables;
describe orders;

#now both the tables are connected through customer_id whic is a foreign key 

#now the next table is order_items can we create it right now?  NO
#cause it is a juncitont able connecting orders and products which have many to many rleatinship
#it also acts as a junction table for not only products but also sellers
#a junction table resolves many to many relationship and convert it to one to many relationship which is easy to enforce

#so the next table can be seller as it has no foreign key and it is one of the master table

create table seller(
seller_id char(32) primary key,
seller_zip_code_prefix int not null, 
seller_city varchar(100) not null,
seller_state char(2) not null
);

#now next tale would be produc cause order_items depends on this table so this is also a master table kinda.
#but this product table in olist(the one we downloaded) does not have relationship with seller id becuase the seller and the prod
#have many to many relationship which we discussed above so we are gonna use the order_items for this also 

create table product(
product_id char(32) primary key,
product_category_name varchar(100) ,
product_name_length int,
product_description_length int, 
product_photos_quantity int,
product_weight_g int,
product_length_cm int, 
product_height_cm int, 
product_width_cm int

);

#now we can create the juncion table whic is order_items because we have now seller , order, and products table but we first go to 
#create independent tables which are prodcategory_translation and geolocation they are look up table as the gelocation used zip_code to be look into from other
#tables and the prod_cateogry_translation used name to be looked into by othr tables and get the translation name

#but again we go for orde_items table first to create the whole connection of order, prod, seller and this order_items

#this table represents every individual product inside an order
create table order_items(
order_id CHAR(32) NOT NULL,

    order_item_id INT NOT NULL,

    product_id CHAR(32) NOT NULL,

    seller_id CHAR(32) NOT NULL,

    shipping_limit_date DATETIME NOT NULL,

    price DECIMAL(10,2) NOT NULL,

    freight_value DECIMAL(10,2) NOT NULL,
    
    #the follwoing is compsoite key now here is the thing in this table we have order_id and product_id and seller _id they cant be 
    #primary key as they are foreign key also there is this order_item_id now the thing is that it is not unique as for every order
    #it start again from 1 2 3 .. so we take order_id with order_item_id both make a unique combination 
    
    
    
    primary key (order_id, order_item_id),
    
    constraint fk_order_items_orders
		foreign key (order_id)
		references orders(order_id),
        
	#this table reference to 3 tables as we discussed above  so constraints are also 3
    constraint fk_order_items_products
    foreign key(product_id)
    references product(product_id),

	constraint fk_order_items_seller
    foreign key (seller_id)
    references seller(seller_id)
);


show tables;
describe order_items;

#adding payment table this table answers how payment was made 

CREATE TABLE payments (

    order_id CHAR(32) NOT NULL,

    payment_sequential INT NOT NULL,

    payment_type VARCHAR(20) NOT NULL,

    payment_installments INT NOT NULL,

    payment_value DECIMAL(10,2) NOT NULL,
    
    #the same constraint discussed above here order is not unique and pament_sequential is unique for eaco order but it starts again from 1 even 
    #order is changed
    
    primary key(order_id, payment_sequential),

	CONSTRAINT fk_payments_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)

);
show tables;
#now at this point we have implementd entire purchasing processs

describe payments;


#a customer places an order
#the order contains the product from seller
#and the customer pays for the products so these all tables are there above

#now we are proceeding to the review table which is the customer feedback about an order
#this represents the feedback about entire purchasing experience not just a product

#as a review belongs to an order so thats why it will have a foreign key to the order table 

create table reviews(
review_id char(32) primary key,
order_id char(32) not null,
review_score int not null,
review_comment_title varchar(255),
review_comment_message TEXT,
review_creation_date datetime not null,
#nullable cause not every review receives answer
review_answer_timestamp Datetime,

constraint fk_reviews_orders
foreign key(order_id)
references orders(order_id)
);

show tables;
describe reviews;


#another table is product_category_translation not a transaction table but a lookup table which just convbe used to convert the name into enlgish from portuguese

#now this table does not have any id but it does have name category name and product also have cateogry name so we are gonna use this column to get the translation 
#name from this table 

#so we will be using name as a primary key

create table product_category_translation (
product_category_name varchar(100) primary key,
product_category_name_english varchar(100) not null);

show tables;

#geolocation table  final table as we have zip code in customer and seller table we can use this table as areference to find the location(like latitude and 
#longitude) of #the seller and customers using the zip_code as  matching column

#now this table has a problem it lacks the primary key but there is zipcode but zip code is  duplicate here in this lookup table 
#because in saem zip code we ave diff laitutde and longitude for the same customer so it can be repeated 

#thats why we are gonna create a surrogate key which will act as a primary key 


 #when investigating this table as a reference table in the python we found that zip_code_can be used as a matching column because 
 #it is shared with both the table like cusotmer and seller but it is not unique  like if we find the customer exact coordinates
 # then we face the issue
 #After investigating the real data, we discovered:

/*
Customer
   │
   │ ZIP = 1001
   ▼
Geolocation
   ├── 1001 / coordinate A
   ├── 1001 / coordinate B
   ├── 1001 / coordinate C
   └── 1001 / coordinate D
 
 */
 # so our data cant support a foreign key relationship hereas it returns multiple records for a single cusotmer zip code so we dont know 
 #which exact coordinates is our cusotmer belongs to?
 #this is explined in detail there in the documentation.
 
 #but we can find the state of a cusomter and seller using this lookup table so that is the purpose of this table not exact coordinated of a 
 #customer as zip_code is repeated but can find the state.
 
 
create table geolocation(
geolocation_id int auto_increment primary key,
geolocation_zip_code_prefix int not null,

#decimals is high because the lat and lng require high precision
geolocation_lat Decimal(10, 8) not null,
geolocation_lng Decimal(10,8) not null,
geolocation_city varchar(100) not null,
geolocation_state char(2) not null);


show tables;


#display the reviews table to fix the primary key
#as we Discovered in python this cant be primary key because it contains duplicates
show create table reviews;

#lets fix this and make this compsote key

alter Table reviews
drop primary key,
add primary key (review_id, order_id);	


#display the changes

#importing the data to the tables 
#the manual method is pretty slow so lets do this in python with pymysql library

show create table reviews;

#Delete from customer;

select * from customer;

#set sql_safe_updates = 0;


#the data is loaded through python in transformation notebook as manual method was slow

select count(*) as total_customers from customer;

#now next is order table first lets check the order table if its empty
#importing orders after customers because customer is a master table and orders having foreign relatinshop with cusomter with foreign key


select * from orders;

#next we are going for product table as order_item depends on product and order table
#so before order_item product and order table should be there

select * from product;
select count(*) as total_product from product;

#next is seller as order_items also depends on this 
show tables;
select count(*) as total_seller from seller;

#next we are going for order_items as that table depends on these above 3 tables that we just imported the data

#order item

select count(*) as total_order_items from order_items;

#checking composite keys

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) AS unique_composite_keys
FROM order_items;

#so no duplicate composite key
#done with order_items table 

#payment table 
select count(*) as total_rows from payments;

#next is reviews as review depends on order so order table is already loaded alter

select count(*) as total_reviews from reviews;

#so main transactional tables are done now we move to lookup tables which are geolocation and cateogry translation

#Table geolocation 

select count(*) as total_loc from geolocation;

#table category translation

show tables;

select * from product_category_translation;

select count(*) as total_translation from product_category_translation;

#so all tables and data is imported finally we are done with it.

#for queres we are gonna use another file







