-- month
-- product name
-- variant
-- sold quatity
-- gross price per item
-- gross price total

# Complete report of 70002017 of fiscal year 2021 
select 
	s.date,s.product_code,
    s.sold_quantity,p.product,p.variant,
    f.gross_price,
    round(f.gross_price* s.sold_quantity) as gross_price_total
from fact_sales_monthly s
join dim_product p
	on p.product_code = s.product_code 
join fact_gross_price f
	on f.product_code = s.product_code and f.fiscal_year = get_fiscal_year (s.date)
where customer_code = 70002017 and get_fiscal_year (date) = 2021;



# gross_total_price group by fiscal_year
select 
	s.date, sum(g.gross_price*sold_quantity) as gross_total_price
from fact_sales_monthly s 
join fact_gross_price g 
	on g.product_code = s.product_code and
		g.fiscal_year = get_fiscal_year (s.date) 
where customer_code = 90002002
group by s.date;


# get fiscal_year and total gross_total amount
select 
	get_fiscal_year(date), 
    sum(g.gross_price*s.sold_quantity) as gross_total
from fact_sales_monthly s
join fact_gross_price g 
	on get_fiscal_year(s.date) = g.fiscal_year
    and g.product_code =s.product_code
where customer_code = 90002002
group by get_fiscal_year (date);



#create gross sales report  HW
select 
	s.date,s.fiscal_year,
    s.customer_code, c.customer, c.market,
    s.product_code,p.product, p.variant,
    s.sold_quantity,
    (g.gross_price*s.sold_quantity) as gross_price_total
from fact_sales_monthly s 
join dim_customer c 
	on s.customer_code = c.customer_code
join dim_product p
	on p.product_code = s.product_code
join fact_gross_price g
	on g.product_code = s.product_code
    and g.fiscal_year =s.fiscal_year;
    
    
 #create views such as net_sales, sales_preinv_discount and sales-postinv_discount to analyze the record  
SELECT 
	s.date, s.fiscal_year, s.customer_code, s.sold_quantity,
    p.product, p.variant,
    c.market,
    g. product_code, (g.gross_price*s.sold_quantity) as gross_price_total,
    pr.pre_invoice_discount_pct 
FROM fact_sales_monthly s 
join fact_gross_price g 
	on g.product_code =s.product_code
    and g.fiscal_year =s.fiscal_year
join fact_pre_invoice_deductions pr
	on pr.customer_code =s.customer_code
    and pr.fiscal_year =s.fiscal_year
join dim_product p
	on p.product_code =s.product_code
join dim_customer c 
	on c.customer_code =s.customer_code;



SELECT pr.*,
	(1-pre_invoice_discount_pct) * gross_price_total as net_invoice_sales,
    (po.discounts_pct+po.other_deductions_pct) as post_total_discount
    
FROM sales_pre_invoice_discount pr
join fact_post_invoice_deductions po 
	on po.customer_code = pr.customer_code
    and po.date = pr.date
    and po.product_code = pr.product_code;
    

SELECT *,
	(1- post_total_discount)*net_invoice_sales as net_sales
FROM sales_postinv_discount 
;

# created store procedure to get top_n_market based on the fiscal_year 

SELECT market,
round(sum(net_sales/1000000),2) as total_net_mln

FROM net_sales
where fiscal_year = 2021
group by market
order by total_net_mln desc
limit 5 ;

# created store procedure to get total_net_mln of the customer based on the fiscal_year through customer_code
SELECT customer,
round(sum(net_sales/1000000),2) as total_net_mln

FROM net_sales n
join dim_customer c
on c.customer_code = n.customer_code
where fiscal_year = 2021
group by c.customer
order by total_net_mln desc
limit 5 ;


# customer pct by global total_net_mln sales
with cte1  as (
			SELECT customer,
		round(sum(net_sales/1000000),2) as total_net_mln

		FROM net_sales n
		join dim_customer c
		on c.customer_code = n.customer_code
		where fiscal_year = 2021
		group by c.customer 
        )
	select
    *,
   (total_net_mln * 100/ sum(total_net_mln) over ()) as pct
    from cte1
    order by total_net_mln desc; 
    
    
  # customer pct by region  
with cte1 as (
	SELECT customer,
c.region,
		round(sum(net_sales/1000000),2) as total_net_mln

		FROM net_sales n
		join dim_customer c
		on c.customer_code = n.customer_code
		where n.fiscal_year = 2021
		group by c.customer, c.region)
        
select *,
	(total_net_mln * 100)/ sum(total_net_mln) over (partition by region) as pct
from cte1
        order by total_net_mln desc;

# top product make pct using dense_rank
with cte1 as(
SELECT 
		p.product,p.division, 
		sum(s.sold_quantity) as total_qty

FROM dim_product p 
join fact_sales_monthly s 
	on s.product_code = p.product_code
where fiscal_year = 2021
group by p.product, p.division) ,
 cte2  as (
select *,
	dense_rank () over(partition by division order by total_qty desc) as drk
from cte1)
select * from cte2 where drk<=3;


#hw find top 2 market by region from thier gross_sales_mln
with cte1 as (SELECT c.market, c.region,
	round(sum(g.gross_price * s.sold_quantity)/1000000 , 2) as gross_sales_mln

FROM fact_sales_monthly s 
join fact_gross_price g
	on g.product_code =s.product_code
    and g.fiscal_year = s.fiscal_year
join dim_customer c 
	on c.customer_code = s.customer_code
where s.fiscal_year = 2021
group by c.market, c.region),

cte2 as (

select* , dense_rank () over (partition by region order by gross_sales_mln desc) as drnk
from cte1)

select* from cte2 where drnk <3; 



# create and join the tables with all the values for net_error and abs_error
create table fact_act_est
(
SELECT 
	s.date,
    s.fiscal_year, 
    s.product_code,s.customer_code,
    s.sold_quantity, f.forecast_quantity

FROM fact_sales_monthly s
left join fact_forecast_monthly f 
using (product_code, customer_code, date)

union

SELECT 
	f.date,
    f.fiscal_year, 
    f.product_code,f.customer_code,
    s.sold_quantity, f.forecast_quantity

FROM fact_forecast_monthly f 
left join fact_sales_monthly s  
using (product_code, customer_code, date)

);




# create abs forecast_accuracy table 
with forecast_err_table as (
             select
                  s.customer_code as customer_code,
                  c.customer as customer_name,
                  c.market as market,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             join dim_customer c
             on s.customer_code = c.customer_code
             where s.fiscal_year=2021
             group by customer_code
	)
	select 
            *,
            if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
	from forecast_err_table
        order by forecast_accuracy desc;

#give grant to specific users to acces the database
show grants for 'smit'





