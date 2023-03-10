/*
This are some different metrics that I have derived from the FMCG Data. Some teminology are used here is describe as below:
*************
Line fill rate = total lines delivered / total lines ordered   Where one line can have one or more numbers of items.
Volume fill rate = total quantity delivered / total quantity ordered 
On Time Delivery = When all ordered line items are deliverd inside of oreder is delivered on time 
In Full Delivery = An oreder is in full when all the line item items inside the order are delivered in full. 
On Time In Full = An oreder is OTIF only when all the line items inside the order are delivered In Full and On Time. 
*************
Quries are as below:
1.
This first query is to find line fill rate for perticular customer in city on a perticuar day. I have make Stored Procedures as well 
which will ask you to enter customer name and city, and you will have your line rate for that customer in city. 
****************/
WITH cte1 AS (
SELECT order_id,order_qty, delivery_qty,customer_id, customer_name,city,order_placement_date,
	CASE
		WHEN order_qty = delivery_qty then 1
        ELSE 0
	END AS line
FROM fact_order_lines fol
LEFT JOIN dim_customers dc USING (customer_id)
-- WHERE order_id = 'FMR33320501'
ORDER BY order_id
),
cte2 AS (
SELECT *,
	SUM(line) OVER(PARTITION BY order_id) AS order_lines_fulfilled,
    COUNT(line) OVER(PARTITION BY order_id) AS total_order_lines_ordered,
    ROW_NUMBER() OVER(PARTITION BY order_id) AS rnum
FROM cte1
-- WHERE customer_name = 'atlas stores' AND city = 'surat'
)
SELECT order_id,customer_id,customer_name,city,order_placement_date, order_lines_fulfilled, total_order_lines_ordered, ROUND(order_lines_fulfilled*100/ total_order_lines_ordered,2) AS line_fill_rate 
FROM cte2
WHERE rnum = 1

/*************
2.
This first query is to find volume fill rate for perticular customer in city on a perticuar day. I have make Stored Procedures as well 
which will ask you to enter customer name and city, and you will have your volume rate for that customer in city. 

*************/
SELECT order_id,customer_id,customer_name,city,order_placement_date,
	SUM(order_qty) AS total_shipped_qty,
    SUM(delivery_qty) AS total_delivered_qty,
    ROUND(SUM(delivery_qty)*100/SUM(order_qty),2) AS volume_fill_rate
FROM fact_order_lines fol
LEFT JOIN dim_customers dc USING (customer_id)
-- WHERE customer_name = 'atlas stores' AND city = 'ahmedabad'
GROUP BY order_id
ORDER BY city, customer_name

/**********
3.
This query is for On Time In Full to compare its target with actual what they got per month. 

**********/
WITH cte1 AS (
select customer_id,customer_name,city,month,otif_target, `On Time In Full`,
	COUNT(*) OVER(PARTITION BY customer_id,month) AS total_month_otif,
	SUM(`On Time In Full`) OVER(PARTITION BY customer_id,month) AS actual_otif,
    ROW_NUMBER() OVER(PARTITION BY customer_id,month) AS rnum
from fact_order_lines fol
left join dim_targets_orders dto USING (customer_id)
LEFT JOIN dim_customers dc USING (customer_id)
-- WHERE customer_name = 'Vijay Stores' AND city = 'Surat' AND month = 'august'
)
SELECT customer_id,customer_name,city,month,otif_target,
	ROUND(actual_otif*100/total_month_otif,2) AS pct_actual_month_otif
FROM cte1
WHERE rnum = 1

/***************
4.
This is for line fill rate per product.
***************/

WITH cte1 AS
(
SELECT product_id,product_name,
	CASE
		WHEN order_qty = delivery_qty then 1
        ELSE 0
	END AS line
FROM fact_order_lines fol
LEFT JOIN dim_products USING (product_id)
),
cte2 AS
(
SELECT *,
	COUNT(line) OVER(PARTITION BY product_id) AS total_order_line,
    SUM(line) OVER(PARTITION BY product_id) AS total_delivered_line,
    ROW_NUMBER() OVER(PARTITION BY product_id) AS rnum
FROM cte1
-- WHERE product_id = 25891101
)
SELECT product_id,product_name, ROUND(total_delivered_line*100/total_order_line,2) AS pct_lifr_per_product
FROM cte2
WHERE rnum = 1

/**************
5.
This one is to find volume fill rate per product.
**************/
WITH cte1 AS
(
SELECT product_id,product_name,
	SUM(order_qty) AS total_shipped_qty,
    SUM(delivery_qty) AS total_delivered_qty,
    ROUND(SUM(delivery_qty)*100/SUM(order_qty),2) AS volume_fill_rate
FROM fact_order_lines fol
LEFT JOIN dim_products dc USING (product_id)
-- WHERE product_id = 
GROUP BY product_id
ORDER BY product_id
)
SELECT product_id, product_name, volume_fill_rate
FROM cte1

/***************
6.
This one finds you On Time In Full per day for perticular store in city.
***************/
WITH cte1 AS 
( 
SELECT customer_id,customer_name,city ,order_placement_date,`On Time In Full`,
	COUNT(*) OVER(PARTITION BY customer_name, city, order_placement_date) AS orders_per_day,
    SUM(`On Time In Full`) OVER(PARTITION BY customer_name, city, order_placement_date) AS total_otif_per_day,
    ROW_NUMBER() OVER(PARTITION BY customer_name, city, order_placement_date) AS raw_number
FROM fact_order_lines fol
JOIN dim_customers dc USING (customer_id)
-- WHERE customer_name = 'Vijay Stores' AND city = 'Ahmedabad'
)
SELECT customer_id,customer_name, city,order_placement_date,orders_per_day,total_otif_per_day,
	CONCAT(ROUND(total_otif_per_day*100/orders_per_day,2),'%') AS pct_otif_per_day
FROM cte1
WHERE raw_number = 1

/****************
7.
This one is for OTIF actual vs target for each store in city.
****************/
WITH cte1 AS
(
SELECT customer_id,customer_name,city, 
	dto.ontime_target , dto.infull_target , dto.otif_target,
    COUNT(*) OVER(PARTITION BY customer_id,city) AS total_order,
    SUM(`In Full`) OVER(PARTITION BY customer_id,city) AS actual_infull,
    SUM(`On Time`) OVER(PARTITION BY customer_id,city) AS actual_ontime,
    SUM(`On Time In Full`) OVER(PARTITION BY customer_id) AS actual_otif,
    ROW_NUMBER() OVER(PARTITION BY customer_id) AS rnum
FROM fact_order_lines fol
JOIN dim_targets_orders dto USING (customer_id)
JOIN dim_customers dc USING (customer_id)
-- WHERE customer_name = 'Vijay Stores' AND city = 'Surat'
ORDER BY customer_id
LIMIT 10000000
)
SELECT *,
	ROUND(actual_infull*100/total_order,2) AS actual_infull_pct,
    ROUND(actual_ontime*100/total_order,2) AS actual_ontime_pct,
    ROUND(actual_otif*100/total_order,2) AS actual_otif_pct
FROM cte1 c
WHERE rnum = 1


