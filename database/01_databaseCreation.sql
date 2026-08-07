
#this way because it wont be break if we run it again and again 

create database IF NOT EXISTS brazilian_ecommerce_analytics
character set utf8mb4
collate utf8mb4_unicode_ci;

#charcter set is used becuase we have names in potuguese and in engish 
#while the collation is how text is compared and sorted  ci stands for  case insensitive 
#also how special marks on letter is handled in searching like here in names are in portuggues so thats why there are special 
#marks on the letter

use brazilian_ecommerce_analytics;
show databases;
select database();




